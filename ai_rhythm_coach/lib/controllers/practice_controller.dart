import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/practice_state.dart';
import '../models/session.dart';
import '../services/audio_service.dart';
import '../services/rhythm_analyzer.dart';
import '../services/ai_coaching_service.dart';
import '../services/session_manager.dart';

class PracticeController extends ChangeNotifier {
  PracticeState _state = PracticeState.idle;
  int _bpm = 120; // Default tempo
  Session? _currentSession;
  String? _errorMessage;
  int _recordingTimeRemaining = 60; // Countdown timer

  // Services (injected)
  final AudioService _audioService;
  final RhythmAnalyzer _rhythmAnalyzer;
  final AICoachingService _aiCoachingService;
  final SessionManager _sessionManager;

  PracticeController({
    required AudioService audioService,
    required RhythmAnalyzer rhythmAnalyzer,
    required AICoachingService aiCoachingService,
    required SessionManager sessionManager,
  })  : _audioService = audioService,
        _rhythmAnalyzer = rhythmAnalyzer,
        _aiCoachingService = aiCoachingService,
        _sessionManager = sessionManager;

  // Getters
  PracticeState get state => _state;
  int get bpm => _bpm;
  Session? get currentSession => _currentSession;
  String? get errorMessage => _errorMessage;
  int get recordingTimeRemaining => _recordingTimeRemaining;

  // Start practice session with 4-beat count-in
  Future<void> startSession() async {
    try {
      _setState(PracticeState.countIn);
      _errorMessage = null;

      // Initialize audio service if not already initialized
      await _audioService.initialize();

      // Play 4-beat count-in
      await _audioService.playCountIn(_bpm);

      // Start recording + metronome simultaneously
      _setState(PracticeState.recording);
      await _audioService.startRecording();
      await _audioService.startMetronome(_bpm);

      // Countdown timer for 60 seconds
      _recordingTimeRemaining = 60;
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(seconds: 1));
        _recordingTimeRemaining--;
        notifyListeners();
      }

      // Stop recording + metronome
      final audioFilePath = await _audioService.stopRecording();
      await _audioService.stopMetronome();

      // Process results
      await _processSession(audioFilePath);
    } catch (e) {
      _handleError(e);
    }
  }

  // Process recorded audio to generate coaching
  Future<void> _processSession(String audioFilePath) async {
    try {
      _setState(PracticeState.processing);

      // Analyze rhythm
      final tapEvents = await _rhythmAnalyzer.analyzeAudio(
        audioFilePath: audioFilePath,
        bpm: _bpm,
        durationSeconds: 60,
      );

      // Check if we have enough tap events
      if (tapEvents.isEmpty) {
        throw Exception(
            'No beats detected. Please:\n'
            '• Tap louder (clap your hands or hit a surface firmly)\n'
            '• Check that microphone permission is granted\n'
            '• Make sure headphones are connected (so metronome doesn\'t interfere)\n'
            '• Ensure you\'re actually making sound during the recording');
      }

      // Warn if very few beats detected (might indicate problem)
      final expectedBeats = (60 * _bpm / 60).round(); // Expected beats in 60 seconds
      if (tapEvents.length < expectedBeats * 0.2) { // Less than 20% of expected
        print('Warning: Only ${tapEvents.length} beats detected (expected ~$expectedBeats). '
            'User may not be tapping consistently or loud enough.');
      }

      // Calculate metrics
      final averageError = RhythmAnalyzer.calculateAverageError(tapEvents);
      final consistency = RhythmAnalyzer.calculateConsistency(tapEvents);

      // Generate AI coaching
      final coachingText = await _aiCoachingService.generateCoaching(
        bpm: _bpm,
        tapEvents: tapEvents,
        averageError: averageError,
        consistency: consistency,
      );

      // Create session object
      _currentSession = Session(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        bpm: _bpm,
        durationSeconds: 60,
        audioFilePath: audioFilePath,
        tapEvents: tapEvents,
        averageError: averageError,
        consistency: consistency,
        coachingText: coachingText,
      );

      // Save session
      await _sessionManager.saveSession(_currentSession!);

      _setState(PracticeState.completed);
    } catch (e) {
      _handleError(e);
    }
  }

  // Update BPM setting
  void setBpm(int newBpm) {
    if (newBpm >= 40 && newBpm <= 200) {
      _bpm = newBpm;
      notifyListeners();
    }
  }

  // Reset to idle state
  void reset() {
    _state = PracticeState.idle;
    _currentSession = null;
    _errorMessage = null;
    _recordingTimeRemaining = 60;
    notifyListeners();
  }

  // Update state and notify listeners
  void _setState(PracticeState newState) {
    _state = newState;
    notifyListeners();
  }

  // Handle errors
  void _handleError(dynamic error) {
    _state = PracticeState.error;

    if (error is AudioRecordingException) {
      _errorMessage = error.message;
    } else if (error is AIServiceException) {
      _errorMessage = error.message;
    } else {
      _errorMessage = 'An unexpected error occurred: ${error.toString()}';
    }

    notifyListeners();
  }

  // Stop current session (if recording)
  Future<void> stopSession() async {
    if (_state == PracticeState.recording) {
      try {
        await _audioService.stopRecording();
        await _audioService.stopMetronome();
        reset();
      } catch (e) {
        _handleError(e);
      }
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}

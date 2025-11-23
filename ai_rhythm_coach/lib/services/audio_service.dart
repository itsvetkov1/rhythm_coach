import 'dart:async';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecordingException implements Exception {
  final String message;
  AudioRecordingException(this.message);
  @override
  String toString() => 'AudioRecordingException: $message';
}

class AudioService {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  Timer? _metronomeTimer;
  int _beatCount = 0;
  String? _currentRecordingPath;

  bool _isInitialized = false;

  // Initialize audio session
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw AudioRecordingException(
            'Microphone permission denied. Please enable it in settings.');
      }

      _recorder = FlutterSoundRecorder();
      _player = FlutterSoundPlayer();

      await _recorder!.openAudioSession();
      await _player!.openAudioSession();

      _isInitialized = true;
    } catch (e) {
      throw AudioRecordingException('Failed to initialize audio: $e');
    }
  }

  // Cleanup resources
  Future<void> dispose() async {
    _metronomeTimer?.cancel();
    _metronomeTimer = null;

    if (_recorder != null) {
      if (_recorder!.isRecording) {
        await _recorder!.stopRecorder();
      }
      await _recorder!.closeAudioSession();
      _recorder = null;
    }

    if (_player != null) {
      if (_player!.isPlaying) {
        await _player!.stopPlayer();
      }
      await _player!.closeAudioSession();
      _player = null;
    }

    _isInitialized = false;
  }

  // Play 4-beat count-in
  Future<void> playCountIn(int bpm) async {
    if (!_isInitialized) {
      throw AudioRecordingException('AudioService not initialized');
    }

    final interval = Duration(milliseconds: (60000 / bpm).round());

    for (int i = 0; i < 4; i++) {
      try {
        // Play high click for count-in
        await _player!.startPlayer(
          fromURI: 'assets/audio/click_high.wav',
          codec: Codec.pcm16WAV,
          whenFinished: () {},
        );
        await Future.delayed(interval);
      } catch (e) {
        throw AudioRecordingException('Failed to play count-in: $e');
      }
    }
  }

  // Start recording to file
  Future<void> startRecording() async {
    if (!_isInitialized) {
      throw AudioRecordingException('AudioService not initialized');
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/recording_$timestamp.aac';

      await _recorder!.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.aacADTS,
      );
    } catch (e) {
      throw AudioRecordingException('Failed to start recording: $e');
    }
  }

  // Stop recording and return file path
  Future<String> stopRecording() async {
    if (!_isInitialized) {
      throw AudioRecordingException('AudioService not initialized');
    }

    try {
      await _recorder!.stopRecorder();
      if (_currentRecordingPath == null) {
        throw AudioRecordingException('No recording path available');
      }
      return _currentRecordingPath!;
    } catch (e) {
      throw AudioRecordingException('Failed to stop recording: $e');
    }
  }

  // Start metronome click track
  Future<void> startMetronome(int bpm) async {
    if (!_isInitialized) {
      throw AudioRecordingException('AudioService not initialized');
    }

    final interval = Duration(milliseconds: (60000 / bpm).round());
    _beatCount = 0;

    _metronomeTimer = Timer.periodic(interval, (timer) async {
      _beatCount++;

      try {
        // Play high click on beat 1, low click on others
        final clickFile = (_beatCount % 4 == 1)
            ? 'assets/audio/click_high.wav'
            : 'assets/audio/click_low.wav';

        await _player!.startPlayer(
          fromURI: clickFile,
          codec: Codec.pcm16WAV,
          whenFinished: () {},
        );
      } catch (e) {
        // Continue metronome even if one click fails
      }
    });
  }

  // Stop metronome
  Future<void> stopMetronome() async {
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
    _beatCount = 0;
  }

  // Play recorded audio file
  Future<void> playRecording(String filePath) async {
    if (!_isInitialized) {
      throw AudioRecordingException('AudioService not initialized');
    }

    try {
      await _player!.startPlayer(
        fromURI: filePath,
        codec: Codec.aacADTS,
        whenFinished: () {},
      );
    } catch (e) {
      throw AudioRecordingException('Failed to play recording: $e');
    }
  }

  // Stop playback
  Future<void> stopPlayback() async {
    if (_player != null && _player!.isPlaying) {
      await _player!.stopPlayer();
    }
  }

  // Check if currently recording
  bool get isRecording => _recorder?.isRecording ?? false;

  // Check if currently playing
  bool get isPlaying => _player?.isPlaying ?? false;
}

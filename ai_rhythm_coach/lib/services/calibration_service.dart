import 'dart:async';
import 'package:record/record.dart';
import 'package:metronome/metronome.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalibrationService {
  AudioRecorder? _recorder;
  final Metronome _metronome = Metronome();
  String? _currentRecordingPath;
  StreamSubscription<int>? _tickSubscription;

  static const String _latencyKey = 'audio_latency_ms';
  static const int _calibrationBpm = 90;
  static const int _calibrationBeats = 12; // 4 count-in + 8 measured

  bool _isInitialized = false;
  bool _isCurrentlyRecording = false;

  // Initialize service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw Exception('Microphone permission denied');
      }

      _recorder = AudioRecorder();

      await _metronome.init(
        'assets/audio/click_low.wav',
        accentedPath: 'assets/audio/click_high.wav',
        bpm: _calibrationBpm,
        volume: 100,
        enableTickCallback: true,
        timeSignature: 4,
        sampleRate: 44100,
      );

      await _configureAudioRouting();

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize calibration service: $e');
    }
  }

  // Configure audio routing (same as AudioService)
  Future<void> _configureAudioRouting() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ));
    } catch (e) {
      // Non-fatal: audio routing may still work with default settings
    }
  }

  // Dispose resources
  Future<void> dispose() async {
    await _tickSubscription?.cancel();
    _tickSubscription = null;
    await _metronome.stop();
    if (_isCurrentlyRecording) {
      await _recorder?.stop();
      _isCurrentlyRecording = false;
    }
    await _recorder?.dispose();
    _recorder = null;
    _isInitialized = false;
  }

  // Start calibration process
  // Returns the path to the recorded file
  Future<String> startCalibration() async {
    if (!_isInitialized) throw Exception('Service not initialized');

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/calibration_$timestamp.wav';

      // Start recording with WAV/PCM16 (same as AudioService)
      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
        bitRate: 128000,
        echoCancel: false,
        noiseSuppress: false,
        autoGain: false,
      );

      await _recorder!.start(config, path: _currentRecordingPath!);
      _isCurrentlyRecording = true;

      // Start metronome for calibration clicks
      await _metronome.setBPM(_calibrationBpm);

      int beatsPlayed = 0;
      final completer = Completer<void>();

      _tickSubscription = _metronome.tickStream.listen((int tick) {
        beatsPlayed++;
        if (beatsPlayed >= _calibrationBeats && !completer.isCompleted) {
          completer.complete();
        }
      });

      await _metronome.play();

      return _currentRecordingPath!;
    } catch (e) {
      throw Exception('Failed to start calibration: $e');
    }
  }

  Future<String> stopCalibration() async {
    await _tickSubscription?.cancel();
    _tickSubscription = null;
    await _metronome.pause();

    if (_isCurrentlyRecording) {
      await _recorder?.stop();
      _isCurrentlyRecording = false;
    }

    return _currentRecordingPath ?? '';
  }

  // Save latency to preferences
  Future<void> saveLatency(int latencyMs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_latencyKey, latencyMs);
  }

  // Get stored latency
  Future<int> getLatency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_latencyKey) ?? 0;
  }

  // Get calibration parameters
  int get calibrationBpm => _calibrationBpm;
  int get calibrationBeats => _calibrationBeats;
}

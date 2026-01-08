import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalibrationService {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  Timer? _metronomeTimer;
  String? _currentRecordingPath;
  String? _clickHighPath;
  String? _clickLowPath;
  
  static const String _latencyKey = 'audio_latency_ms';
  static const int _calibrationBpm = 90;
  static const int _calibrationBeats = 12; // 4 count-in + 8 measured

  bool _isInitialized = false;

  // Initialize service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw Exception('Microphone permission denied');
      }

      _recorder = FlutterSoundRecorder();
      _player = FlutterSoundPlayer();

      await _recorder!.openRecorder();
      await _player!.openPlayer();

      await _configureAudioRouting();

      _clickHighPath = await _loadAssetToLocalFile('assets/audio/click_high.wav', 'click_high.wav');
      _clickLowPath = await _loadAssetToLocalFile('assets/audio/click_low.wav', 'click_low.wav');

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
            AVAudioSessionCategoryOptions.allowBluetoothA2dp |
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
    } catch (e) {
      print('CalibrationService: Failed to configure audio session: $e');
    }
  }

  Future<String> _loadAssetToLocalFile(String assetPath, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    if (await file.exists()) return file.path;
    final byteData = await rootBundle.load(assetPath);
    await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    return file.path;
  }

  // Dispose resources
  Future<void> dispose() async {
    _metronomeTimer?.cancel();
    if (_recorder != null) {
      if (_recorder!.isRecording) await _recorder!.stopRecorder();
      await _recorder!.closeRecorder();
    }
    if (_player != null) {
      if (_player!.isPlaying) await _player!.stopPlayer();
      await _player!.closePlayer();
    }
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

      // Start recording
      await _recorder!.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.pcm16WAV,
      );

      // Start metronome sequence
      _playCalibrationClicks();
      
      return _currentRecordingPath!;
    } catch (e) {
      throw Exception('Failed to start calibration: $e');
    }
  }

  void _playCalibrationClicks() {
    int beatsPlayed = 0;
    final interval = Duration(milliseconds: (60000 / _calibrationBpm).round());

    _metronomeTimer = Timer.periodic(interval, (timer) async {
      beatsPlayed++;

      if (beatsPlayed > _calibrationBeats) {
        timer.cancel();
        // We don't stop recording here, the controller will do it after a short delay
        return;
      }

      try {
        final clickFile = (beatsPlayed <= 4 || (beatsPlayed - 4) % 4 == 1)
            ? _clickHighPath
            : _clickLowPath;

        await _player!.startPlayer(
          fromURI: clickFile,
          codec: Codec.pcm16WAV,
          whenFinished: () {},
        );
      } catch (e) {
        print('Error playing click: $e');
      }
    });
  }

  Future<String> stopCalibration() async {
    _metronomeTimer?.cancel();
    if (_recorder!.isRecording) {
      await _recorder!.stopRecorder();
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

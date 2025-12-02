import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
  String? _clickHighPath;
  String? _clickLowPath;

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

      await _recorder!.openRecorder();
      await _player!.openPlayer();

      // Note: Audio routing is handled automatically by the OS
      // When headphones are connected, audio output automatically routes to headphones
      // while recording input comes from the built-in microphone
      // This physical separation prevents metronome from being recorded

      _clickHighPath = await _loadAssetToLocalFile('assets/audio/click_high.wav', 'click_high.wav');
      _clickLowPath = await _loadAssetToLocalFile('assets/audio/click_low.wav', 'click_low.wav');

      _isInitialized = true;
    } catch (e) {
      throw AudioRecordingException('Failed to initialize audio: $e');
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

  // Cleanup resources
  Future<void> dispose() async {
    _metronomeTimer?.cancel();
    _metronomeTimer = null;

    if (_recorder != null) {
      if (_recorder!.isRecording) {
        await _recorder!.stopRecorder();
      }
      await _recorder!.closeRecorder();
      _recorder = null;
    }

    if (_player != null) {
      if (_player!.isPlaying) {
        await _player!.stopPlayer();
      }
      await _player!.closePlayer();
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
          fromURI: _clickHighPath,
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
      _currentRecordingPath = '${directory.path}/recording_$timestamp.wav';

      // Log device info
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        print('AudioService: Recording on device: ${androidInfo.manufacturer} ${androidInfo.model} (${androidInfo.device})');
      }

      print('AudioService: Starting recording to $_currentRecordingPath');

      await _recorder!.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.pcm16WAV,
      );
      print('AudioService: Recorder started successfully');
    } catch (e) {
      print('AudioService: Failed to start recording: $e');
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
      print('AudioService: Recording stopped');
      if (_currentRecordingPath == null) {
        throw AudioRecordingException('No recording path available');
      }

      // Verify the file exists and has content
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        final fileSize = await file.length();
        print('AudioService: Recording saved to $_currentRecordingPath');
        print('AudioService: File size: $fileSize bytes');

        if (fileSize < 100) {
          print('WARNING: Recording file is very small ($fileSize bytes) - may be empty or corrupted');
        }
      } else {
        print('ERROR: Recording file does not exist at $_currentRecordingPath');
        throw AudioRecordingException('Recording file was not created');
      }

      return _currentRecordingPath!;
    } catch (e) {
      print('AudioService: Failed to stop recording: $e');
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
            ? _clickHighPath
            : _clickLowPath;

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
        codec: Codec.pcm16WAV,
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

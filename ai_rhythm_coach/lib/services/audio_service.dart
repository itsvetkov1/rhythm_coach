import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'native_audio_recorder.dart';

class AudioRecordingException implements Exception {
  final String message;
  AudioRecordingException(this.message);
  @override
  String toString() => 'AudioRecordingException: $message';
}

class AudioService {
  // Use native Android AudioRecord for recording (full AGC control)
  NativeAudioRecorder? _nativeRecorder;
  // Keep flutter_sound for metronome playback
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

      // Initialize native recorder with VOICE_RECOGNITION source (minimal AGC)
      _nativeRecorder = NativeAudioRecorder();
      final recorderInitialized = await _nativeRecorder!.initialize(
        audioSource: NativeAudioRecorder.AUDIO_SOURCE_VOICE_RECOGNITION,
      );

      if (!recorderInitialized) {
        throw AudioRecordingException('Failed to initialize native audio recorder');
      }

      print('AudioService: Native AudioRecord initialized with VOICE_RECOGNITION source');
      print('AudioService: This provides minimal AGC and better control over audio input');

      // Initialize flutter_sound player for metronome
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();

      // Configure audio routing to ensure proper separation
      await _configureAudioRouting();

      _clickHighPath = await _loadAssetToLocalFile('assets/audio/click_high.wav', 'click_high.wav');
      _clickLowPath = await _loadAssetToLocalFile('assets/audio/click_low.wav', 'click_low.wav');

      _isInitialized = true;
    } catch (e) {
      throw AudioRecordingException('Failed to initialize audio: $e');
    }
  }

  // Configure audio focus and routing for proper input/output separation
  Future<void> _configureAudioRouting() async {
    try {
      // Get the audio session instance
      final session = await AudioSession.instance;

      // Configure audio session for simultaneous playback and recording
      // Key settings:
      // - allowBluetooth: Enables Bluetooth headphone routing
      // - allowBluetoothA2dp: Enables high-quality Bluetooth audio
      // - defaultToSpeaker: REMOVED to prefer headphones when available
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.allowBluetoothA2dp,
        avAudioSessionMode: AVAudioSessionMode.measurement, // Minimal audio processing
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

      print('AudioService: Audio session configured');
      print('AudioService: Category: playAndRecord, Mode: measurement (minimal processing)');
      print('AudioService: Options: Bluetooth enabled, no defaultToSpeaker (prefers headphones)');

      // Log current audio routing
      await _logAudioRouting(session);

    } catch (e) {
      print('AudioService: Failed to configure audio session: $e');
      print('AudioService: App will attempt to use default routing');
    }
  }

  // Log current audio routing to help diagnose issues
  Future<void> _logAudioRouting(AudioSession session) async {
    try {
      final devices = await session.getDevices();
      print('AudioService: === Audio Routing Info ===');
      print('AudioService: Available output devices:');
      for (final device in devices) {
        print('AudioService:   - ${device.name} (${device.type})');
      }

      // Check if headphones are connected
      final hasHeadphones = devices.any((d) =>
          d.type == AudioDeviceType.bluetoothA2dp ||
          d.type == AudioDeviceType.wiredHeadphones ||
          d.type == AudioDeviceType.wiredHeadset);

      if (hasHeadphones) {
        print('AudioService: Headphones/Bluetooth DETECTED - metronome will use them');
      } else {
        print('AudioService: WARNING: NO headphones detected!');
        print('AudioService: WARNING: Metronome will play through SPEAKER');
        print('AudioService: WARNING: Microphone will likely pick up metronome (audio bleed)');
      }
      print('AudioService: ========================');
    } catch (e) {
      print('AudioService: Could not query audio devices: $e');
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

    // Release native recorder
    if (_nativeRecorder != null) {
      await _nativeRecorder!.release();
      _nativeRecorder = null;
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
        print('AudioService: Android SDK: ${androidInfo.version.sdkInt}');
      }

      print('AudioService: Starting NATIVE recording to $_currentRecordingPath');
      print('AudioService: Using native Android AudioRecord API');
      print('AudioService: Audio source: VOICE_RECOGNITION (minimal AGC)');
      print('AudioService: Sample rate: 44100 Hz, Mono, PCM 16-bit');

      final success = await _nativeRecorder!.startRecording(_currentRecordingPath!);

      if (!success) {
        throw AudioRecordingException('Native recorder failed to start');
      }

      print('AudioService: Native recorder started successfully');
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
      print('AudioService: Stopping native recorder');

      final path = await _nativeRecorder!.stopRecording();

      if (path == null) {
        throw AudioRecordingException('Native recorder returned null path');
      }

      // Verify the file exists and has content
      final file = File(path);
      if (await file.exists()) {
        final fileSize = await file.length();
        print('AudioService: Recording saved to $path');
        print('AudioService: File size: $fileSize bytes');

        if (fileSize < 100) {
          print('WARNING: Recording file is very small ($fileSize bytes) - may be empty or corrupted');
        }
      } else {
        print('ERROR: Recording file does not exist at $path');
        throw AudioRecordingException('Recording file was not created');
      }

      _currentRecordingPath = path;
      return path;
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
  bool get isRecording => _nativeRecorder?.isRecording ?? false;

  // Check if currently playing
  bool get isPlaying => _player?.isPlaying ?? false;
}

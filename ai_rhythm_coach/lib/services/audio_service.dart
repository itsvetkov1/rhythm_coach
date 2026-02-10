import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:metronome/metronome.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecordingException implements Exception {
  final String message;
  AudioRecordingException(this.message);
  @override
  String toString() => 'AudioRecordingException: $message';
}

class AudioService {
  AudioRecorder? _recorder;
  final Metronome _metronome = Metronome();
  String? _currentRecordingPath;
  bool _isInitialized = false;
  bool _isCurrentlyRecording = false;
  StreamSubscription<int>? _tickSubscription;

  /// Initialize audio session, recorder, and metronome.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw AudioRecordingException(
          'Microphone permission denied. Please enable it in settings.');
    }

    // Create recorder
    _recorder = AudioRecorder();

    // Initialize metronome with custom click sounds
    await _metronome.init(
      'assets/audio/click_low.wav',
      accentedPath: 'assets/audio/click_high.wav',
      bpm: 120,
      volume: 100,
      enableTickCallback: true,
      timeSignature: 4,
      sampleRate: 44100,
    );

    // Configure audio session AFTER constructing recorder and metronome
    await _configureAudioSession();

    _isInitialized = true;
  }

  /// Configure audio session for simultaneous recording and playback.
  Future<void> _configureAudioSession() async {
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
  }

  /// Play a 4-beat count-in using the metronome, then leave metronome running.
  ///
  /// The metronome continues playing after count-in completes so recording
  /// starts with the metronome already running.
  Future<void> playCountIn(int bpm) async {
    if (!_isInitialized) {
      throw AudioRecordingException('AudioService not initialized');
    }

    await _metronome.setBPM(bpm);

    final completer = Completer<void>();
    int countInBeats = 0;

    _tickSubscription = _metronome.tickStream.listen((int tick) {
      countInBeats++;
      if (countInBeats >= 4 && !completer.isCompleted) {
        completer.complete();
      }
    });

    await _metronome.play();
    await completer.future;
    await _tickSubscription?.cancel();
    _tickSubscription = null;
    // Metronome keeps playing -- recording starts now
  }

  /// Start recording audio to a WAV file.
  ///
  /// Records mono 44100 Hz PCM16 WAV with all DSP disabled (echoCancel,
  /// noiseSuppress, autoGain) to preserve onset transients for RhythmAnalyzer.
  Future<void> startRecording() async {
    if (!_isInitialized) {
      throw AudioRecordingException('AudioService not initialized');
    }

    final directory = await getApplicationDocumentsDirectory();
    _currentRecordingPath =
        '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

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
  }

  /// Stop recording and return the path to the WAV file.
  ///
  /// Validates that the file exists and is non-empty before returning.
  Future<String> stopRecording() async {
    if (!_isInitialized) {
      throw AudioRecordingException('AudioService not initialized');
    }

    final path = await _recorder!.stop();
    _isCurrentlyRecording = false;

    if (path == null || path.isEmpty) {
      throw AudioRecordingException(
          'Recording failed - no file path returned');
    }

    // Verify file exists and has meaningful content
    final file = File(path);
    if (!await file.exists()) {
      throw AudioRecordingException(
          'Recording file was not created at: $path');
    }

    final fileSize = await file.length();
    if (fileSize < 100) {
      throw AudioRecordingException(
          'Recording file is too small ($fileSize bytes) - may be empty or corrupted');
    }

    return path;
  }

  /// Start the metronome at the given BPM.
  ///
  /// This is separate from count-in. Used when metronome needs to be
  /// started or restarted independently.
  Future<void> startMetronome(int bpm) async {
    await _metronome.setBPM(bpm);
    await _metronome.play();
  }

  /// Stop (pause) the metronome.
  Future<void> stopMetronome() async {
    await _metronome.pause();
  }

  /// Dispose all audio resources.
  Future<void> dispose() async {
    await _tickSubscription?.cancel();
    _tickSubscription = null;
    await _metronome.stop();
    await _recorder?.dispose();
    _recorder = null;
    _isCurrentlyRecording = false;
    _isInitialized = false;
  }

  /// Whether a recording session is currently active.
  bool get isRecording => _isCurrentlyRecording;

  /// Whether audio playback is active.
  ///
  /// Returns false for now -- playback of recordings is not needed in Phase 1.
  bool get isPlaying => false;

  /// Validates a WAV file has correct headers and non-empty PCM16 audio data.
  /// Throws AudioRecordingException if validation fails.
  Future<void> validateWavFile(String filePath, {int? expectedDurationSec}) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw AudioRecordingException('Recording file not found: $filePath');
    }

    final bytes = await file.readAsBytes();

    // Minimum WAV header is 44 bytes
    if (bytes.length < 44) {
      throw AudioRecordingException(
        'Recording file too small (${bytes.length} bytes) - likely empty or corrupt');
    }

    // Check RIFF header
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (riff != 'RIFF' || wave != 'WAVE') {
      throw AudioRecordingException(
        'Invalid WAV file - missing RIFF/WAVE headers');
    }

    // Find and validate data chunk
    int offset = 12;
    bool foundData = false;
    while (offset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = bytes[offset + 4] |
          (bytes[offset + 5] << 8) |
          (bytes[offset + 6] << 16) |
          (bytes[offset + 7] << 24);

      if (chunkId == 'data') {
        foundData = true;
        if (chunkSize <= 0) {
          throw AudioRecordingException(
            'WAV file has empty data chunk - no audio was recorded');
        }

        // Check expected size if duration provided
        // WAV at 44100 Hz, 16-bit mono = ~88200 bytes/sec
        if (expectedDurationSec != null) {
          final expectedMinSize = (expectedDurationSec * 44100 * 2 * 0.5).toInt();
          if (chunkSize < expectedMinSize) {
            print('WARNING: Recording shorter than expected '
                '($chunkSize bytes, expected ~${expectedDurationSec * 88200} bytes for ${expectedDurationSec}s)');
          }
        }
        break;
      }

      offset += 8 + chunkSize;
      if (chunkSize % 2 == 1) offset += 1; // WAV chunks are word-aligned
    }

    if (!foundData) {
      throw AudioRecordingException(
        'Invalid WAV file - no data chunk found');
    }
  }
}

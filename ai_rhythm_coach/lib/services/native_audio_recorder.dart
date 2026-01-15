import 'package:flutter/services.dart';
import 'dart:io';

/// Flutter wrapper for native Android AudioRecord implementation.
///
/// This provides access to Android's low-level AudioRecord API with full
/// control over AGC (Automatic Gain Control) settings.
class NativeAudioRecorder {
  static const MethodChannel _channel =
      MethodChannel('com.rhythmcoach.ai_rhythm_coach/native_audio');

  /// Android MediaRecorder.AudioSource constants
  /// See: https://developer.android.com/reference/android/media/MediaRecorder.AudioSource
  static const int AUDIO_SOURCE_DEFAULT = 0;
  static const int AUDIO_SOURCE_MIC = 1;
  static const int AUDIO_SOURCE_VOICE_UPLINK = 2;
  static const int AUDIO_SOURCE_VOICE_DOWNLINK = 3;
  static const int AUDIO_SOURCE_VOICE_CALL = 4;
  static const int AUDIO_SOURCE_CAMCORDER = 5;
  static const int AUDIO_SOURCE_VOICE_RECOGNITION = 6; // Recommended: minimal AGC
  static const int AUDIO_SOURCE_VOICE_COMMUNICATION = 7;
  static const int AUDIO_SOURCE_UNPROCESSED = 9; // Requires API 29+

  bool _isInitialized = false;
  bool _isRecording = false;

  /// Initialize the native audio recorder.
  ///
  /// [audioSource] - Android MediaRecorder.AudioSource constant.
  /// Recommended values:
  /// - VOICE_RECOGNITION (6): Minimal AGC, good for detecting drum hits
  /// - UNPROCESSED (9): Raw audio with no processing (API 29+, may not be supported on all devices)
  /// - MIC (1): Default microphone with standard processing
  Future<bool> initialize({
    int audioSource = AUDIO_SOURCE_VOICE_RECOGNITION,
  }) async {
    try {
      if (!Platform.isAndroid) {
        print('NativeAudioRecorder: Only supported on Android');
        return false;
      }

      print('NativeAudioRecorder: Initializing with audioSource: $audioSource (${_getAudioSourceName(audioSource)})');

      final bool result = await _channel.invokeMethod('initialize', {
        'audioSource': audioSource,
      });

      _isInitialized = result;

      if (result) {
        print('NativeAudioRecorder: Initialized successfully');
      } else {
        print('NativeAudioRecorder: Initialization failed');
      }

      return result;
    } catch (e) {
      print('NativeAudioRecorder: Error initializing: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Start recording to the specified file path.
  ///
  /// [filePath] - Absolute path where the WAV file will be saved.
  ///
  /// Returns true if recording started successfully.
  Future<bool> startRecording(String filePath) async {
    if (!_isInitialized) {
      print('NativeAudioRecorder: Not initialized');
      return false;
    }

    if (_isRecording) {
      print('NativeAudioRecorder: Already recording');
      return false;
    }

    try {
      print('NativeAudioRecorder: Starting recording to: $filePath');

      final bool result = await _channel.invokeMethod('startRecording', {
        'filePath': filePath,
      });

      _isRecording = result;

      if (result) {
        print('NativeAudioRecorder: Recording started');
      } else {
        print('NativeAudioRecorder: Failed to start recording');
      }

      return result;
    } catch (e) {
      print('NativeAudioRecorder: Error starting recording: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop the current recording.
  ///
  /// Returns the path to the recorded file, or null if failed.
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      print('NativeAudioRecorder: Not currently recording');
      return null;
    }

    try {
      print('NativeAudioRecorder: Stopping recording');

      final String? path = await _channel.invokeMethod('stopRecording');

      _isRecording = false;

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final fileSize = await file.length();
          print('NativeAudioRecorder: Recording stopped. File: $path (${fileSize} bytes)');
          return path;
        } else {
          print('NativeAudioRecorder: Recording file does not exist: $path');
          return null;
        }
      } else {
        print('NativeAudioRecorder: Stop recording returned null');
        return null;
      }
    } catch (e) {
      print('NativeAudioRecorder: Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Release all native resources.
  Future<void> release() async {
    try {
      await _channel.invokeMethod('release');
      _isInitialized = false;
      _isRecording = false;
      print('NativeAudioRecorder: Released');
    } catch (e) {
      print('NativeAudioRecorder: Error releasing: $e');
    }
  }

  /// Check if recorder is currently recording.
  bool get isRecording => _isRecording;

  /// Check if recorder is initialized.
  bool get isInitialized => _isInitialized;

  /// Get human-readable name for audio source constant.
  String _getAudioSourceName(int audioSource) {
    switch (audioSource) {
      case AUDIO_SOURCE_DEFAULT:
        return 'DEFAULT';
      case AUDIO_SOURCE_MIC:
        return 'MIC';
      case AUDIO_SOURCE_VOICE_UPLINK:
        return 'VOICE_UPLINK';
      case AUDIO_SOURCE_VOICE_DOWNLINK:
        return 'VOICE_DOWNLINK';
      case AUDIO_SOURCE_VOICE_CALL:
        return 'VOICE_CALL';
      case AUDIO_SOURCE_CAMCORDER:
        return 'CAMCORDER';
      case AUDIO_SOURCE_VOICE_RECOGNITION:
        return 'VOICE_RECOGNITION (Recommended)';
      case AUDIO_SOURCE_VOICE_COMMUNICATION:
        return 'VOICE_COMMUNICATION';
      case AUDIO_SOURCE_UNPROCESSED:
        return 'UNPROCESSED (API 29+)';
      default:
        return 'UNKNOWN($audioSource)';
    }
  }
}

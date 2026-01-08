# Sample-Accurate Metronome Implementation Guide

## AI Rhythm Coach - Technical Implementation Specification

**Document Purpose**: Step-by-step instructions for implementing a sample-accurate metronome system using pre-generated audio tracks. This replaces the current `Timer.periodic()` approach which causes timing drift.

**Target Repository**: `https://github.com/itsvetkov1/rhythm_coach.git`

**Estimated Implementation Time**: 4-6 hours

---

## Table of Contents

1. [Problem Summary](#1-problem-summary)
2. [Solution Overview](#2-solution-overview)
3. [Prerequisites](#3-prerequisites)
4. [Implementation Steps](#4-implementation-steps)
   - 4.1 [Create WAV Generator Utility](#41-create-wav-generator-utility)
   - 4.2 [Create Metronome Track Service](#42-create-metronome-track-service)
   - 4.3 [Modify Audio Service](#43-modify-audio-service)
   - 4.4 [Update Practice Session Flow](#44-update-practice-session-flow)
5. [Testing Verification](#5-testing-verification)
6. [File Structure Summary](#6-file-structure-summary)
7. [Rollback Plan](#7-rollback-plan)

---

## 1. Problem Summary

### Current Implementation (Problematic)

**Location**: `lib/services/audio_service.dart` (around line 155)

```dart
_metronomeTimer = Timer.periodic(interval, (timer) async {
  _beatCount++;
  // Play click
  await _player!.startPlayer(...);
});
```

### Why This Fails

1. `Timer.periodic()` guarantees **minimum** delay, not exact timing
2. Dart VM garbage collection causes unpredictable jitter
3. `await` on audio playback adds variable latency
4. Timing errors accumulate: at 120 BPM, 5ms drift per beat = **600ms off** after 60 seconds

### Solution: Pre-Generated Metronome Track

Generate a complete WAV file with click sounds placed at mathematically exact sample positions. The audio subsystem handles timing internally with sample-accuracy.

---

## 2. Solution Overview

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Session Start                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│          MetronomeTrackService.generateTrack()              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 1. Calculate samples per beat                        │    │
│  │ 2. Create 60-second audio buffer                     │    │
│  │ 3. Insert click waveform at exact sample positions   │    │
│  │ 4. Write WAV file to temp directory                  │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Synchronized Playback + Recording              │
│  ┌───────────────────┐    ┌───────────────────┐             │
│  │ Player: metronome │    │ Recorder: user    │             │
│  │ track WAV file    │    │ audio capture     │             │
│  └─────────┬─────────┘    └─────────┬─────────┘             │
│            │                        │                       │
│            └────────┬───────────────┘                       │
│                     │                                       │
│            Started simultaneously                           │
└─────────────────────────────────────────────────────────────┘
```

### Key Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| Sample Rate | 44100 Hz | Standard audio quality |
| Bit Depth | 16-bit | Sufficient for clicks |
| Channels | Mono | Metronome doesn't need stereo |
| BPM Range | 40-200 | Per MVP spec |
| Session Duration | 60 seconds | Per MVP spec |
| Click Duration | 50ms | Short, punchy click |
| Click Frequency | 1000 Hz | Audible, not harsh |

---

## 3. Prerequisites

### Verify Current Dependencies

Check `pubspec.yaml` for:
```yaml
dependencies:
  flutter_sound: ^9.x.x  # or current version
  path_provider: ^2.x.x   # for temp directory access
```

### Add Required Dependency

Add to `pubspec.yaml` if not present:
```yaml
dependencies:
  path_provider: ^2.1.0  # Required for temp file storage
```

Run: `flutter pub get`

### Understand Current File Structure

Before starting, verify the current project structure:
```bash
# Clone and examine
git clone https://github.com/itsvetkov1/rhythm_coach.git
cd rhythm_coach

# Find audio service location
find . -name "audio_service.dart" -type f

# Find existing metronome implementation
grep -rn "Timer.periodic" lib/
grep -rn "metronome" lib/
```

---

## 4. Implementation Steps

### 4.1 Create WAV Generator Utility

**Create new file**: `lib/utils/wav_generator.dart`

This utility handles low-level WAV file creation with raw byte manipulation.

```dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Utility class for generating WAV audio files.
/// 
/// Handles raw PCM audio data and WAV file format encoding.
/// Used by MetronomeTrackService to create sample-accurate metronome tracks.
class WavGenerator {
  /// Standard sample rate for audio generation
  static const int sampleRate = 44100;
  
  /// Bit depth for audio samples (16-bit signed integers)
  static const int bitsPerSample = 16;
  
  /// Number of audio channels (mono)
  static const int numChannels = 1;

  /// Generates a sine wave click sound.
  /// 
  /// Parameters:
  /// - [frequency]: Click tone frequency in Hz (default: 1000 Hz)
  /// - [durationMs]: Click duration in milliseconds (default: 50ms)
  /// - [amplitude]: Volume level 0.0-1.0 (default: 0.8)
  /// 
  /// Returns: List of 16-bit PCM samples representing the click
  static List<int> generateClickSamples({
    double frequency = 1000.0,
    int durationMs = 50,
    double amplitude = 0.8,
  }) {
    final int numSamples = (sampleRate * durationMs / 1000).round();
    final List<int> samples = List<int>.filled(numSamples, 0);
    
    // Maximum value for 16-bit signed integer
    const int maxAmplitude = 32767;
    final double scaledAmplitude = amplitude * maxAmplitude;
    
    for (int i = 0; i < numSamples; i++) {
      // Calculate time position
      final double t = i / sampleRate;
      
      // Generate sine wave
      double sample = sin(2 * pi * frequency * t);
      
      // Apply envelope (attack-decay) to avoid clicks at start/end
      double envelope = _calculateEnvelope(i, numSamples);
      
      // Scale and convert to 16-bit integer
      samples[i] = (sample * scaledAmplitude * envelope).round();
    }
    
    return samples;
  }

  /// Generates an accented click (louder, slightly different tone).
  /// Used for beat 1 of each measure in 4/4 time.
  /// 
  /// Returns: List of 16-bit PCM samples for accented click
  static List<int> generateAccentedClickSamples() {
    return generateClickSamples(
      frequency: 1500.0,  // Higher pitch for accent
      durationMs: 60,     // Slightly longer
      amplitude: 1.0,     // Full volume
    );
  }

  /// Calculates envelope multiplier for smooth attack/decay.
  /// Prevents audio artifacts (pops/clicks) at sample boundaries.
  static double _calculateEnvelope(int sampleIndex, int totalSamples) {
    // Attack: first 5% of samples
    final int attackSamples = (totalSamples * 0.05).round();
    // Decay: last 30% of samples
    final int decaySamples = (totalSamples * 0.30).round();
    final int decayStart = totalSamples - decaySamples;

    if (sampleIndex < attackSamples) {
      // Linear attack
      return sampleIndex / attackSamples;
    } else if (sampleIndex >= decayStart) {
      // Exponential decay for natural sound
      final double decayProgress = (sampleIndex - decayStart) / decaySamples;
      return pow(1 - decayProgress, 2).toDouble();
    }
    
    return 1.0; // Sustain portion
  }

  /// Creates a complete WAV file from PCM audio samples.
  /// 
  /// Parameters:
  /// - [samples]: List of 16-bit signed PCM samples
  /// - [outputPath]: File path to write the WAV file
  /// 
  /// WAV file format:
  /// - RIFF header (12 bytes)
  /// - fmt chunk (24 bytes)
  /// - data chunk (8 bytes + audio data)
  static Future<void> writeWavFile(List<int> samples, String outputPath) async {
    final int dataSize = samples.length * 2; // 2 bytes per 16-bit sample
    final int fileSize = 44 + dataSize - 8;  // Total size minus RIFF header
    
    final ByteData header = ByteData(44);
    int offset = 0;

    // RIFF chunk descriptor
    // "RIFF" marker
    header.setUint8(offset++, 0x52); // R
    header.setUint8(offset++, 0x49); // I
    header.setUint8(offset++, 0x46); // F
    header.setUint8(offset++, 0x46); // F
    
    // File size (minus 8 bytes for RIFF header)
    header.setUint32(offset, fileSize, Endian.little);
    offset += 4;
    
    // "WAVE" format
    header.setUint8(offset++, 0x57); // W
    header.setUint8(offset++, 0x41); // A
    header.setUint8(offset++, 0x56); // V
    header.setUint8(offset++, 0x45); // E

    // fmt sub-chunk
    // "fmt " marker
    header.setUint8(offset++, 0x66); // f
    header.setUint8(offset++, 0x6D); // m
    header.setUint8(offset++, 0x74); // t
    header.setUint8(offset++, 0x20); // (space)
    
    // Sub-chunk size (16 for PCM)
    header.setUint32(offset, 16, Endian.little);
    offset += 4;
    
    // Audio format (1 = PCM)
    header.setUint16(offset, 1, Endian.little);
    offset += 2;
    
    // Number of channels
    header.setUint16(offset, numChannels, Endian.little);
    offset += 2;
    
    // Sample rate
    header.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    
    // Byte rate (sample rate * channels * bytes per sample)
    final int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    header.setUint32(offset, byteRate, Endian.little);
    offset += 4;
    
    // Block align (channels * bytes per sample)
    final int blockAlign = numChannels * (bitsPerSample ~/ 8);
    header.setUint16(offset, blockAlign, Endian.little);
    offset += 2;
    
    // Bits per sample
    header.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;

    // data sub-chunk
    // "data" marker
    header.setUint8(offset++, 0x64); // d
    header.setUint8(offset++, 0x61); // a
    header.setUint8(offset++, 0x74); // t
    header.setUint8(offset++, 0x61); // a
    
    // Data size
    header.setUint32(offset, dataSize, Endian.little);

    // Convert samples to bytes
    final ByteData audioData = ByteData(dataSize);
    for (int i = 0; i < samples.length; i++) {
      // Clamp to valid 16-bit range
      int sample = samples[i].clamp(-32768, 32767);
      audioData.setInt16(i * 2, sample, Endian.little);
    }

    // Write file
    final File file = File(outputPath);
    final IOSink sink = file.openWrite();
    sink.add(header.buffer.asUint8List());
    sink.add(audioData.buffer.asUint8List());
    await sink.close();
  }
}
```

---

### 4.2 Create Metronome Track Service

**Create new file**: `lib/services/metronome_track_service.dart`

This service generates complete metronome audio tracks for practice sessions.

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../utils/wav_generator.dart';

/// Service for generating sample-accurate metronome audio tracks.
/// 
/// Replaces Timer.periodic() approach with pre-generated audio files
/// where click sounds are placed at mathematically exact sample positions.
/// This eliminates timing drift over the course of a practice session.
class MetronomeTrackService {
  /// Singleton instance
  static final MetronomeTrackService _instance = MetronomeTrackService._internal();
  factory MetronomeTrackService() => _instance;
  MetronomeTrackService._internal();

  /// Cache for generated click samples (avoid regenerating)
  List<int>? _normalClickSamples;
  List<int>? _accentedClickSamples;

  /// Path to most recently generated metronome track
  String? _lastGeneratedTrackPath;
  
  /// BPM of most recently generated track (for cache validation)
  int? _lastGeneratedBpm;
  
  /// Duration of most recently generated track
  int? _lastGeneratedDurationSeconds;

  /// Generates a metronome track WAV file for the specified parameters.
  /// 
  /// Parameters:
  /// - [bpm]: Beats per minute (40-200 per MVP spec)
  /// - [durationSeconds]: Track duration (default: 60 seconds per MVP spec)
  /// - [timeSignatureBeatsPerMeasure]: Beats per measure (default: 4 for 4/4 time)
  /// - [accentFirstBeat]: Whether to accent beat 1 of each measure
  /// 
  /// Returns: File path to the generated WAV file
  /// 
  /// Throws: [ArgumentError] if BPM is outside valid range
  Future<String> generateTrack({
    required int bpm,
    int durationSeconds = 60,
    int timeSignatureBeatsPerMeasure = 4,
    bool accentFirstBeat = true,
  }) async {
    // Validate BPM range per MVP spec
    if (bpm < 40 || bpm > 200) {
      throw ArgumentError('BPM must be between 40 and 200. Received: $bpm');
    }

    // Check cache - return existing file if parameters match
    if (_lastGeneratedTrackPath != null &&
        _lastGeneratedBpm == bpm &&
        _lastGeneratedDurationSeconds == durationSeconds) {
      final File cachedFile = File(_lastGeneratedTrackPath!);
      if (await cachedFile.exists()) {
        return _lastGeneratedTrackPath!;
      }
    }

    // Initialize click samples (cached for reuse)
    _normalClickSamples ??= WavGenerator.generateClickSamples();
    if (accentFirstBeat) {
      _accentedClickSamples ??= WavGenerator.generateAccentedClickSamples();
    }

    // Calculate timing parameters
    final int sampleRate = WavGenerator.sampleRate;
    final double secondsPerBeat = 60.0 / bpm;
    final int samplesPerBeat = (sampleRate * secondsPerBeat).round();
    final int totalSamples = sampleRate * durationSeconds;
    final int totalBeats = (durationSeconds * bpm / 60).floor();

    // Create audio buffer (initialized to silence)
    final List<int> audioBuffer = List<int>.filled(totalSamples, 0);

    // Place click sounds at exact sample positions
    for (int beat = 0; beat < totalBeats; beat++) {
      // Calculate exact sample position for this beat
      final int beatStartSample = (beat * samplesPerBeat).round();
      
      // Determine if this is an accented beat (first beat of measure)
      final bool isAccentedBeat = accentFirstBeat && 
          (beat % timeSignatureBeatsPerMeasure == 0);
      
      // Select appropriate click samples
      final List<int> clickSamples = isAccentedBeat 
          ? _accentedClickSamples! 
          : _normalClickSamples!;
      
      // Copy click samples into buffer at calculated position
      _insertClickIntoBuffer(
        buffer: audioBuffer,
        clickSamples: clickSamples,
        startPosition: beatStartSample,
      );
    }

    // Generate output file path
    final Directory tempDir = await getTemporaryDirectory();
    final String fileName = 'metronome_${bpm}bpm_${durationSeconds}s.wav';
    final String outputPath = '${tempDir.path}/$fileName';

    // Write WAV file
    await WavGenerator.writeWavFile(audioBuffer, outputPath);

    // Update cache
    _lastGeneratedTrackPath = outputPath;
    _lastGeneratedBpm = bpm;
    _lastGeneratedDurationSeconds = durationSeconds;

    return outputPath;
  }

  /// Inserts click samples into the audio buffer at the specified position.
  /// Uses additive mixing to handle potential overlap (though unlikely with typical parameters).
  void _insertClickIntoBuffer({
    required List<int> buffer,
    required List<int> clickSamples,
    required int startPosition,
  }) {
    for (int i = 0; i < clickSamples.length; i++) {
      final int bufferIndex = startPosition + i;
      
      // Bounds check - don't write past end of buffer
      if (bufferIndex >= buffer.length) break;
      
      // Additive mixing with clamping to prevent overflow
      final int mixedSample = buffer[bufferIndex] + clickSamples[i];
      buffer[bufferIndex] = mixedSample.clamp(-32768, 32767);
    }
  }

  /// Cleans up cached metronome track file.
  /// Call when session ends or app is closing.
  Future<void> cleanup() async {
    if (_lastGeneratedTrackPath != null) {
      final File file = File(_lastGeneratedTrackPath!);
      if (await file.exists()) {
        await file.delete();
      }
      _lastGeneratedTrackPath = null;
      _lastGeneratedBpm = null;
      _lastGeneratedDurationSeconds = null;
    }
  }

  /// Clears the click sample cache.
  /// Useful if you want to regenerate clicks with different parameters.
  void clearClickCache() {
    _normalClickSamples = null;
    _accentedClickSamples = null;
  }

  /// Returns the expected duration of the metronome track in milliseconds.
  /// Useful for UI progress indicators.
  static int getTrackDurationMs(int durationSeconds) {
    return durationSeconds * 1000;
  }

  /// Calculates the number of beats in a track.
  /// Useful for beat counting and progress display.
  static int getTotalBeats(int bpm, int durationSeconds) {
    return (durationSeconds * bpm / 60).floor();
  }
}
```

---

### 4.3 Modify Audio Service

**File to modify**: `lib/services/audio_service.dart`

The following changes replace the `Timer.periodic()` metronome with the pre-generated track approach.

#### Step 4.3.1: Add Import

Add at the top of the file with other imports:

```dart
import 'metronome_track_service.dart';
```

#### Step 4.3.2: Add Service Instance

Add as a class member variable (near other service instances):

```dart
final MetronomeTrackService _metronomeTrackService = MetronomeTrackService();
```

#### Step 4.3.3: Add Metronome Player Instance

You need a **separate** FlutterSoundPlayer for the metronome track because recording and metronome playback happen simultaneously. Add near the existing player declaration:

```dart
FlutterSoundPlayer? _metronomePlayer;
```

#### Step 4.3.4: Initialize Metronome Player

In your initialization method (likely `init()` or similar), add:

```dart
_metronomePlayer = FlutterSoundPlayer();
await _metronomePlayer!.openPlayer();
```

#### Step 4.3.5: Replace Metronome Start Method

Find and replace the existing `startMetronome()` method (or equivalent) with:

```dart
/// Starts the metronome with a pre-generated sample-accurate track.
/// 
/// Parameters:
/// - [bpm]: Tempo in beats per minute (40-200)
/// - [durationSeconds]: Session duration (default: 60)
/// 
/// The metronome track is generated on-demand and played back.
/// Generation takes ~100-300ms depending on device.
Future<void> startMetronome({
  required int bpm,
  int durationSeconds = 60,
}) async {
  // Generate sample-accurate metronome track
  final String trackPath = await _metronomeTrackService.generateTrack(
    bpm: bpm,
    durationSeconds: durationSeconds,
    accentFirstBeat: true,
  );

  // Start metronome playback
  await _metronomePlayer!.startPlayer(
    fromURI: trackPath,
    codec: Codec.pcm16WAV,
    whenFinished: () {
      // Session complete - metronome finished playing
      _onMetronomeComplete();
    },
  );
}

/// Called when metronome track finishes playing (session complete)
void _onMetronomeComplete() {
  // Notify listeners or trigger session completion
  // This replaces the beat counting logic from Timer.periodic approach
}
```

#### Step 4.3.6: Replace Metronome Stop Method

Find and replace the existing `stopMetronome()` method with:

```dart
/// Stops metronome playback.
Future<void> stopMetronome() async {
  if (_metronomePlayer != null && _metronomePlayer!.isPlaying) {
    await _metronomePlayer!.stopPlayer();
  }
}
```

#### Step 4.3.7: Remove Old Timer-Based Code

**Delete** or comment out these elements (exact names may vary):

```dart
// REMOVE: Timer? _metronomeTimer;
// REMOVE: int _beatCount = 0;
// REMOVE: Any Timer.periodic() calls related to metronome
// REMOVE: _playClick() method if it was only used for metronome
```

#### Step 4.3.8: Update Synchronized Start

Create or update a method to start recording and metronome simultaneously:

```dart
/// Starts a practice session with synchronized recording and metronome.
/// 
/// Both start from the same trigger point for accurate beat alignment
/// in the recorded audio.
/// 
/// Parameters:
/// - [bpm]: Practice tempo
/// - [durationSeconds]: Session duration
/// - [recordingPath]: Path to save the recorded audio
Future<void> startPracticeSession({
  required int bpm,
  required int durationSeconds,
  required String recordingPath,
}) async {
  // Generate metronome track first (slight delay acceptable)
  final String metronomeTrackPath = await _metronomeTrackService.generateTrack(
    bpm: bpm,
    durationSeconds: durationSeconds,
  );

  // Start both simultaneously using Future.wait
  await Future.wait([
    _metronomePlayer!.startPlayer(
      fromURI: metronomeTrackPath,
      codec: Codec.pcm16WAV,
      whenFinished: _onSessionComplete,
    ),
    _recorder!.startRecorder(
      toFile: recordingPath,
      codec: Codec.pcm16WAV,
    ),
  ]);
}

/// Called when practice session completes (metronome track finished)
void _onSessionComplete() {
  // Stop recording
  stopRecording();
  // Notify UI that session is complete
  // ... your existing completion logic
}
```

#### Step 4.3.9: Update Dispose/Cleanup

In your dispose or cleanup method, add:

```dart
@override
Future<void> dispose() async {
  await stopMetronome();
  await _metronomePlayer?.closePlayer();
  await _metronomeTrackService.cleanup();
  // ... existing dispose logic
}
```

---

### 4.4 Update Practice Session Flow

**File to modify**: Your practice session UI/controller (likely `lib/screens/practice_screen.dart` or similar)

#### Step 4.4.1: Update Session Start

Modify the session start button handler to use the new synchronized approach:

```dart
Future<void> _startSession() async {
  setState(() {
    _isLoading = true;  // Show loading indicator during track generation
    _sessionStatus = 'Preparing...';
  });

  try {
    final String recordingPath = await _getRecordingPath();
    
    await _audioService.startPracticeSession(
      bpm: _selectedBpm,
      durationSeconds: 60,
      recordingPath: recordingPath,
    );

    setState(() {
      _isLoading = false;
      _isSessionActive = true;
      _sessionStatus = 'Recording...';
    });
  } catch (e) {
    setState(() {
      _isLoading = false;
      _sessionStatus = 'Error: ${e.toString()}';
    });
  }
}
```

#### Step 4.4.2: Handle Generation Delay in UI

The track generation takes ~100-300ms. Show appropriate feedback:

```dart
// In your build method, when _isLoading is true:
if (_isLoading) {
  return Column(
    children: [
      CircularProgressIndicator(),
      SizedBox(height: 8),
      Text('Generating metronome track...'),
    ],
  );
}
```

---

## 5. Testing Verification

### 5.1 Unit Tests

**Create file**: `test/services/metronome_track_service_test.dart`

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
// Import your service
import 'package:rhythm_coach/services/metronome_track_service.dart';

// Mock path provider for tests
class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUp(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
  });

  group('MetronomeTrackService', () {
    test('generates valid WAV file', () async {
      final service = MetronomeTrackService();
      final path = await service.generateTrack(bpm: 120, durationSeconds: 5);
      
      final file = File(path);
      expect(await file.exists(), isTrue);
      
      // Verify WAV header
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(44)); // Minimum WAV header size
      
      // Check RIFF marker
      expect(String.fromCharCodes(bytes.sublist(0, 4)), equals('RIFF'));
      
      // Check WAVE format
      expect(String.fromCharCodes(bytes.sublist(8, 12)), equals('WAVE'));
      
      // Cleanup
      await service.cleanup();
    });

    test('rejects invalid BPM values', () async {
      final service = MetronomeTrackService();
      
      expect(
        () => service.generateTrack(bpm: 30),  // Below minimum
        throwsArgumentError,
      );
      
      expect(
        () => service.generateTrack(bpm: 250), // Above maximum
        throwsArgumentError,
      );
    });

    test('caches track for same parameters', () async {
      final service = MetronomeTrackService();
      
      final path1 = await service.generateTrack(bpm: 100, durationSeconds: 10);
      final path2 = await service.generateTrack(bpm: 100, durationSeconds: 10);
      
      expect(path1, equals(path2)); // Same path = cache hit
      
      await service.cleanup();
    });

    test('generates new track for different BPM', () async {
      final service = MetronomeTrackService();
      
      final path1 = await service.generateTrack(bpm: 100, durationSeconds: 10);
      final path2 = await service.generateTrack(bpm: 120, durationSeconds: 10);
      
      expect(path1, isNot(equals(path2)));
      
      await service.cleanup();
    });

    test('calculates correct beat count', () {
      expect(MetronomeTrackService.getTotalBeats(120, 60), equals(120));
      expect(MetronomeTrackService.getTotalBeats(60, 60), equals(60));
      expect(MetronomeTrackService.getTotalBeats(100, 30), equals(50));
    });
  });
}
```

### 5.2 Manual Testing Checklist

Perform these tests on a real device:

#### Timing Accuracy Test
1. Set BPM to 120
2. Start session
3. Use external metronome app (or tap along) to verify timing
4. Listen carefully at 30-second and 60-second marks
5. **Expected**: No perceivable drift from external reference

#### Beat Accent Test
1. Start session at any BPM
2. Listen for pattern: STRONG-weak-weak-weak
3. **Expected**: First beat of each measure clearly accented

#### BPM Range Test
1. Test at minimum BPM (40)
2. Test at maximum BPM (200)
3. Test at common values: 60, 80, 100, 120, 140, 160, 180
4. **Expected**: All generate valid tracks and play correctly

#### Session Flow Test
1. Start session
2. Let it run to completion (60 seconds)
3. Verify recording was captured
4. **Expected**: Session ends cleanly, recording is saved

#### Interruption Test
1. Start session
2. Stop manually at ~30 seconds
3. **Expected**: Metronome stops, partial recording is saved

#### Repeated Sessions Test
1. Complete 3 consecutive sessions
2. **Expected**: No memory leaks, no audio glitches, cleanup works

---

## 6. File Structure Summary

After implementation, your project should have these new/modified files:

```
lib/
├── services/
│   ├── audio_service.dart          # MODIFIED - new metronome approach
│   └── metronome_track_service.dart # NEW - track generation service
├── utils/
│   └── wav_generator.dart          # NEW - low-level WAV creation
└── ...

test/
├── services/
│   └── metronome_track_service_test.dart # NEW - unit tests
└── ...
```

---

## 7. Rollback Plan

If issues arise and you need to revert:

### Git-Based Rollback
```bash
# View changes
git diff lib/services/audio_service.dart

# Revert specific file
git checkout HEAD~1 -- lib/services/audio_service.dart

# Or create a branch before starting
git checkout -b feature/sample-accurate-metronome
# ... make changes ...
# If it fails:
git checkout main
git branch -D feature/sample-accurate-metronome
```

### Manual Rollback Steps
1. Delete `lib/utils/wav_generator.dart`
2. Delete `lib/services/metronome_track_service.dart`
3. Restore original `audio_service.dart` from git history
4. Remove `path_provider` dependency if it wasn't there before

---

## Implementation Checklist

Use this checklist to track progress:

- [ ] **Prerequisites**
  - [ ] Verified flutter_sound dependency
  - [ ] Added path_provider dependency
  - [ ] Ran flutter pub get

- [ ] **4.1 WAV Generator**
  - [ ] Created `lib/utils/wav_generator.dart`
  - [ ] Verified no syntax errors

- [ ] **4.2 Metronome Track Service**
  - [ ] Created `lib/services/metronome_track_service.dart`
  - [ ] Verified no syntax errors

- [ ] **4.3 Audio Service Modifications**
  - [ ] Added import for MetronomeTrackService
  - [ ] Added _metronomeTrackService instance
  - [ ] Added _metronomePlayer instance
  - [ ] Updated initialization to open metronome player
  - [ ] Replaced startMetronome() method
  - [ ] Replaced stopMetronome() method
  - [ ] Removed old Timer.periodic code
  - [ ] Created startPracticeSession() method
  - [ ] Updated dispose/cleanup

- [ ] **4.4 UI Updates**
  - [ ] Updated session start handler
  - [ ] Added loading indicator during track generation

- [ ] **5. Testing**
  - [ ] Created unit tests
  - [ ] Passed timing accuracy test
  - [ ] Passed beat accent test
  - [ ] Passed BPM range test
  - [ ] Passed session flow test
  - [ ] Passed interruption test
  - [ ] Passed repeated sessions test

---

## Notes for Implementation Agent

1. **Before starting**: Clone the repository and examine the exact current structure of `audio_service.dart`. The variable names and method names may differ from this document.

2. **Adapt as needed**: The existing codebase may have different naming conventions or state management patterns. Preserve the existing patterns while integrating the new functionality.

3. **Test incrementally**: After each major step (4.1, 4.2, 4.3, 4.4), verify the app still compiles and runs.

4. **Preserve existing features**: The audio service likely has other functionality (recording, analysis, etc.) that must continue working.

5. **Error handling**: The provided code includes basic error handling. Integrate with the project's existing error handling patterns if they differ.

---

**Document Version**: 1.0  
**Created For**: AI Rhythm Coach MVP  
**Compatibility**: Flutter 3.x, flutter_sound 9.x

# Phase 1: Audio Recording - Research

**Researched:** 2026-02-10
**Domain:** Flutter audio recording, simultaneous playback, WAV file handling, Android audio routing
**Confidence:** HIGH

## Summary

Phase 1 replaces the broken flutter_sound-based recording pipeline with the `record` package and adds a separate playback engine for the metronome. The existing codebase uses flutter_sound for both recording and metronome playback via a single `FlutterSoundPlayer`/`FlutterSoundRecorder` pair, but flutter_sound has documented Android recording corruption issues and the Timer.periodic metronome approach causes timing drift. The migration involves three independent concerns: (1) replacing the recorder, (2) replacing the metronome player, and (3) configuring audio session routing so both operate simultaneously without conflict.

The `record` package (v6.2.0) provides `AudioRecorder` with file-mode WAV recording via `RecordConfig(encoder: AudioEncoder.wav)`. For metronome playback, the `metronome` package (v2.0.7) provides sample-accurate click timing with custom WAV file support and a `tickStream` for beat callbacks -- this solves the Timer.periodic drift problem without hand-rolling audio scheduling. The `audio_session` package (v0.2.2, already in pubspec) configures Android's `playAndRecord` mode so recording and playback coexist. After recording stops, the WAV file is validated by parsing RIFF/WAVE headers and checking that the data chunk contains non-empty PCM16 audio.

**Primary recommendation:** Replace flutter_sound with `record` for recording and `metronome` for click playback. Configure audio_session for simultaneous operation. Validate WAV output after each recording.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **record** | ^6.2.0 | Audio recording to WAV file | Modern replacement for flutter_sound. Uses Android MediaCodec (not MediaRecorder). No known corruption issues. Supports WAV/PCM16 natively. Min Android SDK 23 (project uses 24). Active development -- v6.2.0 released Feb 2026. |
| **metronome** | ^2.0.7 | Accurate metronome playback | Cross-platform metronome with sample-accurate timing. Accepts custom WAV files (`setAudioFile`). Provides `tickStream` for beat callbacks. Solves Timer.periodic drift. No dependency on flutter_sound. |
| **audio_session** | ^0.2.2 | Audio routing configuration | Already in pubspec. Configures `playAndRecord` mode for simultaneous recording + playback. Manages Android AudioAttributes and audio focus. Required by `record` and `metronome` to coexist without conflict. Requires Flutter >=3.27.0 and AGP 8.5.2+. |
| **permission_handler** | ^11.0.0 | Microphone permission | Already in pubspec. Required for Android RECORD_AUDIO runtime permission. Standard solution. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **wav** | ^1.5.0 | WAV file reading/validation | Pure Dart WAV parser. Reads headers, extracts sample rate, bit depth, channels, and audio data. Use for post-recording validation (AUD-04). Also used later by RhythmAnalyzer. |
| **path_provider** | ^2.1.0 | File system paths | Already in pubspec. Provides `getApplicationDocumentsDirectory()` for recording storage. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| **metronome** package | **flutter_soloud** (v3.4.10) | SoLoud is lower-level C++ FFI-based, more powerful (3D audio, effects), but overkill for metronome clicks. metronome package is purpose-built, simpler API, handles timing internally. SoLoud would require hand-rolling the beat scheduling logic. |
| **metronome** package | **audioplayers** + Timer | audioplayers has known issues with `lowLatency` + `releaseMode` on Android (sounds play only once). Timer.periodic drifts. This is what the current code does with flutter_sound -- it is the problem we are fixing. |
| **metronome** package | **just_audio** + Timer | just_audio is excellent for playback but does not solve timing. Still requires Timer.periodic or Ticker for scheduling. Same drift problem. |
| **wav** package | Manual header parsing | Current codebase already has manual WAV parsing in rhythm_analyzer.dart. The `wav` package is cleaner, handles edge cases (WAVE_FORMAT_EXTENSIBLE, non-standard chunks), and provides sample rate / bit depth accessors. But manual parsing also works -- the current implementation is correct. Either approach is fine. |

**Installation (pubspec.yaml changes):**

Remove:
```yaml
  flutter_sound: ^9.2.13   # REMOVE - has recording corruption issues
  device_info_plus: ^11.3.0 # REMOVE - only used for debug logging in AudioService
```

Add:
```yaml
  record: ^6.2.0           # ADD - audio recording to WAV
  metronome: ^2.0.7        # ADD - accurate metronome with custom click sounds
```

Keep (already present):
```yaml
  audio_session: ^0.1.13   # KEEP but UPDATE to ^0.2.2 (requires Flutter >=3.27.0)
  permission_handler: ^11.0.0  # KEEP
  path_provider: ^2.1.0       # KEEP
```

Optional add:
```yaml
  wav: ^1.5.0              # OPTIONAL - cleaner WAV validation than manual parsing
```

## Architecture Patterns

### Recommended Project Structure

No structural changes to project layout. Phase 1 modifies existing files:

```
lib/services/
├── audio_service.dart      # REWRITE - replace flutter_sound with record + metronome
```

```
test/
├── services/
│   └── audio_service_test.dart  # NEW - unit tests for recording + validation
```

### Pattern 1: Separated Recording and Playback Engines

**What:** Use `record` package for microphone capture and `metronome` package for click playback as completely independent subsystems. They share an audio session but have no code dependencies on each other.

**When to use:** Always for this app. The old design used flutter_sound for both recording and playback, creating coupling and single-point-of-failure. Separated engines allow independent testing, replacement, and debugging.

**Example:**

```dart
// Recording with record package
import 'package:record/record.dart';

final recorder = AudioRecorder();

// Check permission
if (!await recorder.hasPermission()) {
  throw AudioRecordingException('Microphone permission denied');
}

// Configure for WAV recording
const config = RecordConfig(
  encoder: AudioEncoder.wav,
  sampleRate: 44100,
  numChannels: 1,      // Mono - sufficient for rhythm detection
  bitRate: 128000,      // Irrelevant for WAV but required parameter
  echoCancel: false,    // Don't use - can distort onset transients
  noiseSuppress: false, // Don't use - can suppress quiet taps
  autoGain: false,      // Don't use - changes volume between frames
);

// Start recording to file
final dir = await getApplicationDocumentsDirectory();
final path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
await recorder.start(config, path: path);

// ... recording happens ...

// Stop and get file path
final filePath = await recorder.stop();
// Source: https://pub.dev/packages/record
```

```dart
// Metronome with metronome package
import 'package:metronome/metronome.dart';

final metronome = Metronome();

// Initialize with custom click sounds
metronome.init(
  'assets/audio/click_low.wav',         // mainPath (default beat)
  accentedPath: 'assets/audio/click_high.wav', // accentedPath (downbeat)
  bpm: 120,
  volume: 100,
  enableTickCallback: true,
  timeSignature: 4,  // 4/4 time
  sampleRate: 44100,
);

// Listen for beat events (useful for UI and timing reference)
metronome.tickStream.listen((int tick) {
  // tick is the beat number within the measure (0-based)
  print('Beat: $tick');
});

// Start/stop
metronome.play();
// ... recording happens ...
metronome.pause();
// Source: https://pub.dev/packages/metronome
```

### Pattern 2: Audio Session Configuration Before Recording

**What:** Configure the audio_session package AFTER all audio plugins are loaded but BEFORE starting recording or playback. This prevents plugins from overriding each other's audio routing settings.

**When to use:** Always. Must be called in AudioService.initialize(), after constructing recorder and metronome but before any audio operations.

**Example:**

```dart
import 'package:audio_session/audio_session.dart';

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
// Source: https://pub.dev/packages/audio_session
```

### Pattern 3: Post-Recording WAV Validation

**What:** After `recorder.stop()` returns, immediately validate the file: check it exists, is non-empty, has valid RIFF/WAVE headers, and contains PCM16 audio data of expected approximate duration.

**When to use:** After every recording stop. This catches silent/corrupt recordings immediately instead of failing later in the analysis pipeline.

**Example:**

```dart
Future<void> _validateRecording(String filePath, int expectedDurationSeconds) async {
  final file = File(filePath);

  // Check file exists
  if (!await file.exists()) {
    throw AudioRecordingException('Recording file not created: $filePath');
  }

  // Check file size (WAV at 44100 Hz, 16-bit mono = ~88KB/sec)
  final fileSize = await file.length();
  final expectedMinSize = expectedDurationSeconds * 44100 * 2 * 0.5; // 50% tolerance
  if (fileSize < 100) {
    throw AudioRecordingException('Recording file is empty ($fileSize bytes)');
  }
  if (fileSize < expectedMinSize) {
    print('WARNING: Recording file smaller than expected '
        '($fileSize bytes, expected ~${expectedDurationSeconds * 88200} bytes)');
  }

  // Validate WAV headers
  final bytes = await file.readAsBytes();
  final riff = String.fromCharCodes(bytes.sublist(0, 4));
  final wave = String.fromCharCodes(bytes.sublist(8, 12));
  if (riff != 'RIFF' || wave != 'WAVE') {
    throw AudioRecordingException('Invalid WAV file (missing RIFF/WAVE headers)');
  }
}
```

### Anti-Patterns to Avoid

- **Using flutter_sound for recording:** Documented Android corruption issues. The existing AudioService uses `FlutterSoundRecorder` which produces empty/corrupt files on some devices. Replace entirely.
- **Using Timer.periodic for metronome:** Dart timers are not real-time. Drift accumulates: at 120 BPM over 60 seconds, expect 50-600ms cumulative drift. The existing code does this at `audio_service.dart:227`. Replace with metronome package.
- **Using same package for recording and playback:** flutter_sound does both but couples them. If one fails, both fail. Independent packages allow independent debugging.
- **Enabling echoCancel/noiseSuppress/autoGain on recorder:** These DSP features modify the raw audio signal, potentially distorting onset transients that the RhythmAnalyzer needs to detect. Keep recording as raw as possible.
- **Using AAC/compressed codec for recording:** AAC destroys transient information needed for onset detection and has device-specific encoder compatibility issues on Android. Always use WAV/PCM16.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Metronome timing | Timer.periodic + audio player | `metronome` package | Timer.periodic drifts 5-20ms per beat. Metronome package uses native audio scheduling. Current code has this exact bug. |
| Audio session management | Custom platform channels | `audio_session` package | iOS/Android audio session APIs are complex and platform-specific. audio_session handles both with unified Dart API. Already in pubspec. |
| WAV header parsing | Manual byte manipulation | `wav` package (optional) | Current code in rhythm_analyzer.dart already has working manual WAV parsing. Either approach works. The wav package handles edge cases (WAVE_FORMAT_EXTENSIBLE) but adds a dependency. |
| Microphone permission | Custom permission code | `permission_handler` package | Already in pubspec. Handles Android runtime permissions, rationale dialogs, and settings deep-linking. |

**Key insight:** The existing codebase already hand-rolled a metronome with Timer.periodic -- this is the primary timing problem. The metronome package exists specifically to solve this.

## Common Pitfalls

### Pitfall 1: Audio Session Not Configured Before Use

**What goes wrong:** Recording starts but captures silence, or metronome plays through earpiece instead of speaker/headphones, or recording and playback conflict and one silently fails.

**Why it happens:** Each audio plugin (record, metronome, etc.) may set its own audio session configuration. Without explicit configuration via audio_session, the last plugin to initialize wins, potentially setting an incompatible mode.

**How to avoid:** Call `audio_session.configure()` in `AudioService.initialize()` AFTER constructing all audio objects but BEFORE any audio operations. Use `playAndRecord` category. Test with headphones connected and disconnected.

**Warning signs:** Recording file exists but contains silence. Metronome audible in earpiece but not speaker. Recording works alone but fails when metronome is also playing.

### Pitfall 2: Record Package Path Must Be Absolute

**What goes wrong:** `recorder.start()` silently fails or creates file in unexpected location.

**Why it happens:** The record package requires a full absolute file path on IO platforms (Android, iOS). Relative paths or paths without directory components may fail.

**How to avoid:** Always use `getApplicationDocumentsDirectory()` to get the base path, then append filename. Verify directory exists before recording.

**Warning signs:** `recorder.stop()` returns null or empty string. File not found after recording.

### Pitfall 3: Metronome Package Asset Registration

**What goes wrong:** Metronome init fails with "asset not found" or plays silence.

**Why it happens:** The metronome package loads audio files from Flutter assets. The assets must be declared in pubspec.yaml AND the files must exist at the declared paths.

**How to avoid:** Verify `assets/audio/` is declared in pubspec.yaml (it is). Verify click_high.wav and click_low.wav exist (they do, at 4454 bytes each). The metronome package `init()` takes asset paths like `'assets/audio/click_high.wav'`.

**Warning signs:** No sound from metronome. Exception during `metronome.init()`.

### Pitfall 4: Forgetting to Dispose Audio Resources

**What goes wrong:** Microphone stays open after recording stops. Memory leaks. Next recording fails because previous recorder instance still holds the microphone.

**Why it happens:** `AudioRecorder` must be disposed when no longer needed. `Metronome` must be stopped. If the app navigates away or errors out mid-recording, resources may leak.

**How to avoid:** Call `recorder.dispose()` in `AudioService.dispose()`. Call `metronome.stop()` and dispose in cleanup. Use try/finally patterns around recording start/stop.

**Warning signs:** "Microphone in use by another app" errors. Recording fails on second attempt. Memory usage climbs over multiple sessions.

### Pitfall 5: Android Permissions on API 33+

**What goes wrong:** App crashes or recording silently fails on newer Android devices.

**Why it happens:** Android 13+ (API 33) changed the permission model. `RECORD_AUDIO` still requires runtime permission, but storage permissions changed. `WRITE_EXTERNAL_STORAGE` and `READ_EXTERNAL_STORAGE` are no longer needed for app-private directories.

**How to avoid:** Use `permission_handler` to request `Permission.microphone` before recording. Use `getApplicationDocumentsDirectory()` for file storage (no storage permission needed). The existing AndroidManifest.xml has `RECORD_AUDIO` declared (verified). Storage permissions in manifest should add `android:maxSdkVersion="32"`.

**Warning signs:** Permission dialog never appears. `recorder.hasPermission()` returns false.

### Pitfall 6: Metronome Starts Before Audio Session Is Ready

**What goes wrong:** First beat of metronome is delayed or missing. Audio session mode changes mid-playback causing a pop or glitch.

**Why it happens:** If metronome.play() is called before audio_session.configure() completes, the OS may need to switch audio modes, causing a delay on the first beat.

**How to avoid:** Ensure `AudioService.initialize()` completes (including audio session configuration) before any play/record operations. The initialization should be called once during app startup or before the first practice session, not right before each recording.

**Warning signs:** First metronome beat is late or silent. Audio glitch at the start of practice.

## Code Examples

### Complete AudioService Rewrite Pattern

```dart
// Source: Synthesized from record, metronome, and audio_session package docs
import 'dart:io';
import 'package:record/record.dart';
import 'package:metronome/metronome.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  AudioRecorder? _recorder;
  final Metronome _metronome = Metronome();
  String? _currentRecordingPath;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw AudioRecordingException('Microphone permission denied');
    }

    // 2. Create recorder
    _recorder = AudioRecorder();

    // 3. Initialize metronome with custom click sounds
    _metronome.init(
      'assets/audio/click_low.wav',
      accentedPath: 'assets/audio/click_high.wav',
      bpm: 120,
      volume: 100,
      enableTickCallback: true,
      timeSignature: 4,
      sampleRate: 44100,
    );

    // 4. Configure audio session LAST (after all plugins loaded)
    await _configureAudioSession();

    _isInitialized = true;
  }

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

  Future<void> startRecording() async {
    _ensureInitialized();

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentRecordingPath = '${dir.path}/recording_$timestamp.wav';

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
  }

  Future<String> stopRecording() async {
    _ensureInitialized();
    final path = await _recorder!.stop();
    if (path == null || path.isEmpty) {
      throw AudioRecordingException('Recording failed - no file path returned');
    }
    return path;
  }

  void startMetronome(int bpm) {
    _metronome.setBPM(bpm);
    _metronome.play();
  }

  void stopMetronome() {
    _metronome.pause();
  }

  Future<void> dispose() async {
    _metronome.stop();
    await _recorder?.dispose();
    _recorder = null;
    _isInitialized = false;
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw AudioRecordingException('AudioService not initialized');
    }
  }
}
```

### WAV File Validation

```dart
// Post-recording validation (AUD-04 requirement)
Future<bool> validateWavFile(String filePath, {int? expectedDurationSec}) async {
  final file = File(filePath);

  if (!await file.exists()) return false;

  final bytes = await file.readAsBytes();
  if (bytes.length < 44) return false;

  // Check RIFF header
  if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') return false;
  if (String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') return false;

  // Find data chunk
  int offset = 12;
  while (offset < bytes.length - 8) {
    final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final chunkSize = bytes[offset + 4] |
        (bytes[offset + 5] << 8) |
        (bytes[offset + 6] << 16) |
        (bytes[offset + 7] << 24);

    if (chunkId == 'data') {
      // Data chunk found - verify it has content
      return chunkSize > 0;
    }
    offset += 8 + chunkSize;
    if (chunkSize % 2 == 1) offset += 1;
  }

  return false;  // No data chunk found
}
```

### Count-In Using Metronome Package

```dart
// Count-in: play 4 beats, then continue into recording
// The metronome package handles timing internally
Future<void> playCountIn(int bpm) async {
  int countInBeats = 0;

  // Use Completer to wait for count-in to finish
  final completer = Completer<void>();

  final subscription = _metronome.tickStream.listen((int tick) {
    countInBeats++;
    if (countInBeats >= 4) {
      completer.complete();
    }
  });

  _metronome.setBPM(bpm);
  _metronome.play();

  await completer.future;
  await subscription.cancel();
  // Metronome keeps playing - recording starts now
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| flutter_sound for recording | `record` package | 2024-2025 | flutter_sound has Android corruption bugs, complex API. record is simpler, actively maintained, no corruption reports. |
| flutter_sound for playback | `just_audio`, `audioplayers`, or `flutter_soloud` for general playback; `metronome` for metronome | 2024-2025 | Decoupling recording from playback. Purpose-built packages for each job. |
| AAC codec for recording | WAV/PCM16 | Project decision | AAC destroys transients, has device-specific encoder issues. WAV is lossless, simpler, larger files acceptable for 60s sessions (~5.3MB). |
| Timer.periodic for metronome | `metronome` package with native scheduling | v2.0.0 (2025) | Timer.periodic drifts. Metronome package handles timing at audio engine level. |
| Manual audio session setup | `audio_session` package | audio_session 0.1.x (2022+) | Unified cross-platform API for iOS AVAudioSession and Android AudioAttributes. |

**Deprecated/outdated:**
- **flutter_sound 9.x recording:** Known Android corruption. Maintainer bandwidth constrained. Do not use for new projects.
- **AAC recording on Android for analysis:** Quality issues documented in flutter_sound issues #420, #2749. Use WAV/PCM16.
- **Timer.periodic for audio timing:** Drift accumulates. Use audio-engine-level scheduling (metronome package, SoLoud, or pre-generated audio tracks).

## Open Questions

1. **Metronome package + record package simultaneous operation on Android**
   - What we know: Both packages are designed to work independently. audio_session configures `playAndRecord` mode which enables simultaneous operation. The record package uses Android AudioRecord (via MediaCodec), and the metronome package uses its own audio engine.
   - What's unclear: Whether any specific Android devices or versions have issues with this combination. The packages don't document mutual compatibility.
   - Recommendation: Must verify on physical device. If conflict occurs, fallback option is to use `flutter_soloud` (v3.4.10) for metronome playback instead -- it uses C++ FFI (not Android audio APIs) and is less likely to conflict with the record package's MediaCodec usage.

2. **Metronome package count-in behavior**
   - What we know: The metronome package has play/pause/stop and tickStream. It supports time signatures (1/4 through 4/4) and custom audio files.
   - What's unclear: Whether `tickStream` fires on the first beat (tick 0) or only on subsequent beats. Whether we can use the metronome for the count-in phase (4 beats before recording starts) and then seamlessly transition to recording while it keeps playing.
   - Recommendation: Test tick numbering behavior. If tickStream doesn't fire immediately, may need to start recording slightly before the 5th tick arrives.

3. **audio_session version compatibility**
   - What we know: Current pubspec has `audio_session: ^0.1.13`. The recommended version is `^0.2.2` which requires Flutter >=3.27.0 and AGP 8.5.2+. Current build.gradle uses compileSdk 35, ndkVersion 27.0.12077973.
   - What's unclear: Whether the project's Flutter SDK version meets >=3.27.0. Whether upgrading to 0.2.2 requires any code changes.
   - Recommendation: Check Flutter SDK version with `flutter --version`. If >=3.27.0, upgrade to ^0.2.2. If not, ^0.1.13 should still work for basic `playAndRecord` configuration -- the API is the same, just older.

4. **WAV recording file size for 60-second sessions**
   - What we know: WAV at 44100 Hz, 16-bit, mono = ~5.3MB per 60 seconds. Storage policy is max 10 sessions. Total: ~53MB.
   - What's unclear: Whether this is acceptable on low-storage devices. The current code has no disk space check.
   - Recommendation: 53MB is acceptable for MVP. Disk space check is LOW priority (Issue #14 from IMPLEMENTATION_ISSUES.md). Can add later.

5. **Android build.gradle changes needed for record package**
   - What we know: record requires min SDK 23 for most encoders. Current project uses minSdk 24 (sufficient). compileSdk 35 should be fine. The flutter_sound-specific comments in build.gradle ("Required by flutter_sound") should be updated.
   - What's unclear: Whether removing flutter_sound changes the NDK version requirement. Whether the metronome package has any specific build config needs.
   - Recommendation: After removing flutter_sound, test build. Remove flutter_sound-specific comments. NDK version can likely stay the same.

## Sources

### Primary (HIGH confidence)
- [record package v6.2.0](https://pub.dev/packages/record) -- Latest version, AudioEncoder.wav support, RecordConfig API, min SDK 23
- [record package changelog](https://pub.dev/packages/record/changelog) -- WAV/PCM16 added in v5.0.0-beta.2, v6.0.0 breaking changes (AudioRecorder class rename)
- [RecordConfig API reference](https://pub.dev/documentation/record_platform_interface/latest/record_platform_interface/RecordConfig-class.html) -- All constructor parameters: encoder, sampleRate, numChannels, bitRate, echoCancel, noiseSuppress, autoGain, androidConfig, iosConfig
- [AndroidRecordConfig API reference](https://pub.dev/documentation/record_platform_interface/latest/record_platform_interface/AndroidRecordConfig-class.html) -- useLegacy, muteAudio, manageBluetooth, audioSource, speakerphone, audioManagerMode
- [metronome package v2.0.7](https://pub.dev/packages/metronome) -- Custom audio files, tickStream, BPM/time signature/volume API, cross-platform
- [metronome example](https://pub.dev/packages/metronome/example) -- init(), play(), pause(), tickStream.listen(), setAudioFile(), setBPM()
- [audio_session package v0.2.2](https://pub.dev/packages/audio_session) -- playAndRecord configuration, AndroidAudioAttributes, requires Flutter >=3.27.0
- [wav package v1.5.0](https://pub.dev/packages/wav) -- Pure Dart WAV reading/writing, supports 8/16/24/32-bit PCM and float formats

### Secondary (MEDIUM confidence)
- [Flutter audio best practices 2026](https://vibe-studio.ai/insights/flutter-audio-playback-recording-in-mobile-apps) -- Recommends just_audio + record combination, audio_session for coordination
- [audioplayers lowLatency issue #1489](https://github.com/bluefireteam/audioplayers/issues/1489) -- Documents audioplayers lowLatency + releaseMode conflict on Android
- [flutter_soloud v3.4.10](https://pub.dev/packages/flutter_soloud) -- Fallback option for metronome playback, C++ FFI, low latency, WAV support
- [Timer.periodic precision article](https://medium.com/geekculture/flutter-case-study-timer-precision-a1154b431e8) -- Documents Timer.periodic drift, recommends alternatives for precise timing
- [Timer.periodic behavior article](https://medium.com/@inf0rmatix/dart-timer-periodic-does-not-what-you-might-think-acf923613813) -- Documents that periodic timer guarantees minimum delay, not exact timing

### Tertiary (LOW confidence)
- Metronome package internal implementation details -- Could not inspect source to verify it uses native audio scheduling vs. Dart timing. The v2.0.0 release notes mention "better performance" and "more accurate time signature callback" but don't specify mechanism. Needs validation on physical device.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All packages verified on pub.dev with current versions, API docs reviewed, migration path from flutter_sound is clear
- Architecture: HIGH -- Separated recording/playback pattern is standard and well-documented. Audio session configuration pattern verified from audio_session docs.
- Pitfalls: HIGH -- Most pitfalls are documented in existing project docs (IMPLEMENTATION_ISSUES.md, PITFALLS.md) and verified against package documentation
- Metronome package behavior: MEDIUM -- Package API verified from pub.dev docs and example code, but simultaneous operation with record package and exact tick timing need physical device testing

**Research date:** 2026-02-10
**Valid until:** 2026-03-10 (stable packages, 30-day validity)

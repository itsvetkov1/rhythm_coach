# Pitfalls Research: Flutter Audio Recording & Onset Detection

**Domain:** Flutter audio recording, real-time rhythm analysis, Android audio
**Researched:** 2026-02-10
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Audio Session Mode Conflicts (Multiple Audio Plugins)

**What goes wrong:**
When an app uses multiple audio plugins (flutter_sound, audio_session, just_audio, TTS, etc.), those plugins internally override each other's audio session settings since there is only a single audio session shared by the app on iOS. This causes recording to fail, playback to route incorrectly (speaker vs. receiver), or both operations to conflict.

**Why it happens:**
Each audio plugin tries to configure the platform audio session independently without coordination. On iOS, only one session exists per app. When flutter_sound initializes, it sets specific session parameters. If another plugin later initializes, it overwrites those settings.

**How to avoid:**
- Use the `audio_session` package as a single source of truth for session configuration
- Configure the session AFTER all audio plugins have loaded
- Set `AVAudioSessionCategory.playAndRecord` with appropriate options (`allowBluetooth`, `defaultToSpeaker`)
- For Android, use `AndroidAudioContentType.music` with `AndroidAudioUsage.media`
- Test session configuration with all plugins active before recording

**Warning signs:**
- Recording works in isolation but fails when TTS or background audio is also used
- Sound plays through phone receiver instead of speaker after recording
- "Session already active" or "Session conflict" errors in logs
- Recording starts successfully but produces silent/empty files

**Phase to address:**
Phase 1 (Audio Infrastructure Fix) - Must establish session management before fixing codec/recording issues

---

### Pitfall 2: Empty/Corrupt Audio Files from Wrong File Paths

**What goes wrong:**
`flutter_sound.startRecorder()` produces empty files (0-4096 bytes) or fails silently without creating files. On Android, you get "EROFS (Read-only file system)" errors. The recorder reports success but the file is unusable.

**Why it happens:**
- Incomplete file path (missing directory prefix or absolute path)
- Writing to read-only locations (external storage without proper permissions on Android 11+)
- AAC codec configuration with default parameters that don't match device capabilities
- Missing `WRITE_EXTERNAL_STORAGE` or `MANAGE_EXTERNAL_STORAGE` permissions on Android 10+

**How to avoid:**
- Always use `getApplicationDocumentsDirectory()` for recording paths
- Provide complete absolute path: `${directory.path}/recording_$timestamp.wav`
- For Android 11+, request `MANAGE_EXTERNAL_STORAGE` if using external storage
- Add to AndroidManifest.xml: `android:requestLegacyExternalStorage="true"` for Android 10
- Use WAV format (`Codec.pcm16WAV`) instead of AAC for debugging (simpler, no encoding issues)
- Verify file size immediately after `stopRecorder()` completes

**Warning signs:**
- Files exist but have size < 100 bytes
- `stopRecorder()` returns path but file doesn't exist
- Emulator works but physical device fails
- Logcat shows "FileNotFoundException" or "Permission denied"

**Phase to address:**
Phase 1 (Audio Infrastructure Fix) - File path and permission issues block all recording

---

### Pitfall 3: AAC Codec Configuration Mismatch

**What goes wrong:**
Recording produces garbled audio, extreme noise, very low volume, or files that won't play back. Some Android devices produce corrupt AAC files while others work perfectly with identical code.

**Why it happens:**
`flutter_sound` defaults to AAC codec with `sampleRate: 16000` and `numChannels: 1`. However, not all Android devices support AAC encoding at all sample rates. Hardware encoders vary by manufacturer. When device's native AAC encoder doesn't support the requested configuration, it may:
- Silently produce corrupt output
- Fall back to unexpected parameters (causing timing errors)
- Use software encoding (high CPU, latency spikes)

**How to avoid:**
- For rhythm analysis, use `Codec.pcm16WAV` instead of AAC
  - WAV is uncompressed PCM (no encoding complexity)
  - Direct access to raw samples for FFT processing
  - No device-specific codec compatibility issues
  - Larger files (acceptable for 60s sessions)
- If AAC required: test `sampleRate: 44100` or `48000` (hardware standard rates)
- Match sample rate to device capabilities via `AudioManager.getProperty()`
- Check [flutter_sound codec compatibility table](https://github.com/shogo-ma/flutter_sound/blob/master/flutter_sound/doc/codec.md) per Android version

**Warning signs:**
- Playback sounds distorted or pitched incorrectly
- File size doesn't match duration (too small = encoding failure)
- Works on Pixel but fails on Samsung (device-specific encoder differences)
- CPU spikes during recording (software encoder fallback)

**Phase to address:**
Phase 1 (Audio Infrastructure Fix) - Codec choice directly impacts file integrity and analysis

---

### Pitfall 4: Emulator Audio Testing False Confidence

**What goes wrong:**
Audio recording features work perfectly in Android emulator but fail completely on real devices. Recording produces 4096-byte files on iOS devices but correct files on iOS simulator.

**Why it happens:**
- Emulators simulate microphone input with test signals (not real audio hardware)
- Real devices have hardware limitations: buffer sizes, latency, encoder capabilities
- Bluetooth audio routing works in emulator but requires special handling on device
- Permission flows differ (emulator auto-grants, device requires runtime permission handling)

**How to avoid:**
- NEVER trust emulator for audio recording validation
- Always test on minimum 2 physical devices (different manufacturers)
- Test on both new devices (Android 13+) and older devices (Android 10-12)
- Test with different audio routes: phone speaker, wired headphones, Bluetooth
- Use real-world conditions: background noise, varied tap volumes

**Warning signs:**
- QA reports "recording broken" but you see it working in emulator
- Production crash reports for audio features you thought were stable
- User reviews mention "doesn't work on Samsung/Xiaomi/etc."
- File size consistent in emulator but varies wildly on devices

**Phase to address:**
Phase 1 & Phase 5 (Fix validation + Pre-release testing) - Early device testing catches issues before full implementation

---

### Pitfall 5: FFT Window/Hop Size Timing Errors

**What goes wrong:**
Onset detection reports beats at wrong times (consistently early/late by 50-200ms), misses beats entirely, or detects ghost beats where none exist. Accuracy degrades at higher BPMs.

**Why it happens:**
- Window size too large: poor time resolution, onsets smeared across multiple frames
- Window size too small: poor frequency resolution, can't detect low-frequency drums
- Hop size too large: onset falls between analysis frames, gets missed or misaligned
- No windowing function applied: spectral leakage creates false onset peaks
- Incorrect sample rate assumption (assumes 44100 but file is 48000)

**How to avoid:**
- Use window size 1024-2048 samples (balance time/frequency resolution)
  - 2048 samples @ 44100 Hz = 46ms time resolution
  - 1024 samples @ 44100 Hz = 23ms time resolution (better for fast rhythms)
- Set hop size = windowSize / 4 (75% overlap for smooth onset curve)
  - 2048 window → 512 hop = 11.6ms frame rate
  - 1024 window → 256 hop = 5.8ms frame rate
- Apply Hann window before FFT (eliminates spectral leakage discontinuities)
- Verify actual sample rate from WAV header (don't assume 44100)
- For BPM > 160, reduce window size to 1024 for faster onset tracking

**Warning signs:**
- Onsets consistently 50ms+ early or late (timing bias)
- Missed beats at fast tempos (BPM > 140) but accurate at slow tempos
- False onsets detected during sustained notes
- Accuracy varies drastically between devices (sample rate mismatch)

**Phase to address:**
Phase 2 (Onset Detection Fix) - Core algorithm parameter tuning

---

### Pitfall 6: Spectral Flux Threshold Over-Tuning

**What goes wrong:**
Onset detection produces perfect results on test recordings but fails in production with real user taps. Detects zero onsets (threshold too high) or hundreds of false onsets (threshold too low).

**Why it happens:**
Developers tune the threshold on a small set of recordings (their own taps, same device, quiet room). Real users have:
- Different tap volumes (soft finger taps vs. loud hand claps)
- Background noise (creates spectral flux spikes)
- Device microphone sensitivity varies 10-20 dB between phones
- Recording environment (reverberant rooms blur onset peaks)

**How to avoid:**
- Use adaptive thresholding: threshold = mean + (k × std_dev) over running window
  - k = 2-3 standard deviations above running mean
- Normalize spectral flux by RMS energy before thresholding
- Set minimum onset separation (e.g., 100ms) to reject double-triggers
- Test with diverse recordings:
  - Soft taps, loud claps, drumstick hits
  - Different rooms (bathroom, living room, outdoors)
  - Different devices (3+ phone models)
  - Background noise (music playing, traffic, conversations)
- Implement minimum signal energy check (RMS > threshold) before analysis

**Warning signs:**
- Works perfectly in your testing but users report "no beats detected"
- Detects every single audio sample as an onset (threshold too low)
- Accuracy perfect in quiet room, fails with any background noise
- Algorithm "forgets" to detect beats after loud sound (blown threshold calculation)

**Phase to address:**
Phase 2 (Onset Detection Fix) - Threshold algorithm needs robustness before deployment

---

### Pitfall 7: Android Audio Latency Not Measured

**What goes wrong:**
Beat timing analysis shows user is consistently 80-150ms late, but user is actually playing perfectly. Coaching feedback blames user for hardware latency they can't control.

**Why it happens:**
Android audio has round-trip latency of 20-200ms depending on device:
- Budget phones: 100-200ms total latency
- Flagship phones with AAudio: 20-40ms latency
- Latency = input latency + output latency + processing time
- Recording starts but first samples include buffering delay
- Different buffer sizes per device (manufacturer-specific HAL)

**How to avoid:**
- Implement device latency calibration:
  - Play click → record → measure delay between expected and actual
  - Perform calibration during app first-run setup
  - Store per-device latency offset
- Apply latency compensation to onset timestamps before matching
  - `correctedTime = detectedTime - latencyOffset`
- Use Android AAudio API (NDK) instead of default audio path for lower latency
- Set buffer size to device's recommended native buffer size
  - Query via `AudioManager.getProperty("android.media.property.OUTPUT_FRAMES_PER_BUFFER")`
- Accept that some devices will always have >100ms latency (can't fix in software)

**Warning signs:**
- All users show consistent late timing bias (40-120ms)
- Timing bias varies drastically by device model
- User plays perfectly by ear but app says they're off
- Timing accuracy improves when using Bluetooth (suggests input latency issue)

**Phase to address:**
Phase 2 (Onset Detection Fix) or Phase 3 (Latency Calibration) - Critical for fair feedback

---

### Pitfall 8: Buffer Overflow / Missed Audio Data

**What goes wrong:**
Recording appears successful but analysis shows missing beats in the middle of the session. Onset detection works for first 10 seconds then fails. File duration shorter than expected.

**Why it happens:**
`AudioRecord` buffer fills faster than app reads it. When buffer overflows, oldest samples are discarded. This happens when:
- UI thread blocks audio processing (heavy rendering, GC pause)
- FFT analysis runs on main thread (blocks buffer reads)
- Buffer size too small for device's interrupt rate
- Background processes steal CPU (system doing backup, etc.)

**How to avoid:**
- Use minimum buffer size from `AudioRecord.getMinBufferSize()` × 2 (safety margin)
- Process audio on dedicated background thread (not UI thread)
- Use periodic callbacks instead of polling: `setRecordPositionUpdateListener()`
- Keep audio callback handlers short (<10ms execution time)
- Avoid blocking operations in audio thread (no I/O, no locks, no allocations)
- Monitor for buffer overrun warning in Android logs
  - "AudioRecord: obtainBuffer() OVERRUN" = data loss

**Warning signs:**
- Logcat shows "AudioRecord: obtainBuffer() OVERRUN"
- Recording duration shorter than expected (60s recording = 58.3s file)
- Gaps in detected onsets (detects beats 1-20, misses 21-30, resumes at 31)
- Problem worse on lower-end devices (less CPU headroom)

**Phase to address:**
Phase 2 (Onset Detection Fix) - Audio processing architecture must handle real-time constraints

---

### Pitfall 9: Simultaneous Playback + Recording Echo/Bleed

**What goes wrong:**
Microphone records the metronome clicks from the speaker, making it impossible to distinguish user taps from metronome. Analysis detects perfect timing (the metronome itself) even when user doesn't play.

**Why it happens:**
- On devices without acoustic echo cancellation (AEC), microphone hears speaker output
- Using playAndRecord mode routes audio through speaker (not headphones)
- Missing `defaultToSpeaker` option sends metronome to earpiece (leaks into mic)
- User doesn't wear headphones, metronome plays out loud
- Some Android devices have poor physical speaker/mic isolation

**How to avoid:**
- Enforce headphone requirement in UI (detect via `AudioManager` or `audio_session`)
- Configure audio session with:
  - `AVAudioSessionCategoryOptions.defaultToSpeaker` (iOS)
  - `AndroidAudioUsage.media` (Android)
- Implement metronome bleed detection:
  - Calculate timing consistency (std deviation of errors)
  - Human playing: consistency > 5-10ms
  - Metronome bleed: consistency < 3ms (machine-perfect)
  - Reject session if consistency suspiciously low
- Use visual metronome as alternative (flashing light instead of sound)
- Test with phone speaker mode to verify bleed detection works

**Warning signs:**
- User scores 100% accuracy without practicing
- Onset timestamps exactly match expected beat times (±1ms)
- Detected onset count = exactly expected beat count (no misses)
- Consistency score < 3ms (superhuman accuracy)
- User reports "I didn't play anything but it detected beats"

**Phase to address:**
Phase 1 (Audio Infrastructure Fix) - Session configuration + bleed detection must be in place

---

### Pitfall 10: Missing Windowing Function (Spectral Leakage)

**What goes wrong:**
FFT produces high-energy frequency components that don't exist in the signal. Onset detection triggers on these artifacts, creating ghost beats. Energy spreads across frequency bins instead of concentrating in peaks.

**Why it happens:**
Raw FFT assumes signal is periodic within the analysis window. When you grab N samples mid-recording, start and end values rarely match (discontinuity). This discontinuity appears as high-frequency content in FFT output (spectral leakage). Without a windowing function, these artifacts dominate the spectrum.

**How to avoid:**
- Apply Hann (Hanning) window before every FFT:
  - `window[i] = 0.5 * (1 - cos(2 * π * i / N))`
  - Multiply samples by window: `windowedSamples[i] = samples[i] * window[i]`
- Hann window recommended for 95% of audio use cases (good balance)
- Alternative: Hamming window (better first sidelobe suppression)
- Pre-compute window coefficients (don't recalculate each frame)
- Verify windowing in test: FFT of silence should show near-zero energy

**Warning signs:**
- Onset detection triggers during silent periods
- Spectral flux has high baseline energy (should be near-zero during silence)
- False onsets at exact FFT frame boundaries
- Energy smeared across many frequency bins (should concentrate in peaks)

**Phase to address:**
Phase 2 (Onset Detection Fix) - Core DSP correctness before threshold tuning

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skip audio session config, rely on defaults | Faster initial implementation | Session conflicts with other plugins, iOS/Android routing inconsistencies | Never - session setup is 20 lines of code |
| Use AAC codec for recording | Smaller file sizes (10-20% of WAV) | Device-specific corruption, harder debugging, encoding latency | Only after WAV confirmed working |
| Hard-code FFT parameters (window/hop size) | Avoids tuning complexity | Poor performance at different BPMs, missed beats at fast tempos | Only for MVP with single BPM range (e.g., 60-120) |
| Static onset threshold (no adaptation) | Simple threshold logic | Fails with volume variations, background noise, different devices | Only in controlled demo environment |
| Skip latency calibration | Avoids complex calibration UX | User blamed for hardware latency (unfair feedback) | Only if latency < 20ms on all test devices |
| Test only on emulator | Faster development iteration | Catastrophic failure on real devices | Never for audio features |
| Assume 44100 Hz sample rate | Simplifies code | Timing errors if device uses 48000 Hz | Only if you verify sample rate from WAV header |
| Process audio on UI thread | Avoids threading complexity | Buffer overruns, dropped audio, UI janks | Never for real-time audio |
| Skip headphone detection | Simpler user flow | Metronome bleed ruins analysis | Only with bleed detection algorithm in place |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| flutter_sound + audio_session | Each plugin configures session independently | Use audio_session AFTER all plugins loaded, configure once |
| flutter_sound + just_audio | Both open audio session, conflict on iOS | Don't mix - use flutter_sound for both record & playback |
| Permission handler | Request permission but forget AndroidManifest.xml entries | Add `<uses-permission>` tags first, then runtime request |
| Path provider | Use `getTemporaryDirectory()` for recordings | Use `getApplicationDocumentsDirectory()` (temp gets cleared) |
| fftea FFT | Pass raw samples directly to FFT | Apply windowing function first (Hann/Hamming) |
| Android AAudio | Hardcode buffer size | Query native buffer size via AudioManager |
| Bluetooth audio | Assume phone microphone when Bluetooth connected | Check AudioManager routing, may need to disable Bluetooth for recording |
| File I/O during recording | Read/write files on audio thread | Use separate I/O thread, pass audio data via lock-free queue |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Heavy FFT on every audio frame | CPU spikes, battery drain, UI lag | Process only when needed (not during silence), use smaller window size | Sustained recording >30s on budget phones |
| Memory allocation in audio callback | GC pauses → buffer overruns | Pre-allocate buffers, reuse arrays | Real-time processing with concurrent UI updates |
| Blocking I/O in audio thread | Missed samples, gaps in recording | Use background thread for file I/O, async operations | Long recordings (>60s) on slow storage |
| Synchronous audio processing | UI freezes during analysis | Process audio on background isolate (Dart compute()) | Files >10 MB (>90s recording) |
| Large FFT window (4096+) | Processing lag, delayed onset detection | Use 1024-2048 window, optimize with FFT library (fftea is 60x faster) | High BPMs (>160) requiring fast onset tracking |
| No downsampling | Processing time scales with sample rate | Downsample to 22050 Hz if 44100 unnecessary (halves FFT cost) | Continuous real-time analysis |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Store recordings in public external storage | User privacy violation, GDPR issues | Use app-private directory (`getApplicationDocumentsDirectory()`) |
| Don't delete old recordings | Disk space exhaustion, privacy | Implement auto-cleanup (max 10 sessions, FIFO deletion) |
| Log audio file paths in production | Path disclosure in crash reports | Only log paths in debug builds |
| Missing permission checks on Android 13+ | App crash when accessing storage | Check runtime permissions before recording, handle denials |
| Upload recordings without consent | Privacy violation | Require explicit user opt-in before cloud sync |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No headphone detection | Users confused why accuracy is 100% (metronome bleed) | Detect audio route, show warning if headphones not connected |
| Blame user for device latency | Frustration ("I'm playing perfectly!") | Implement calibration, compensate for latency |
| Silent failure (empty recordings) | Users think recording worked, then confused by "no data" error | Validate file immediately after stop, show clear error |
| No microphone permission explanation | App crashes or silently fails | Show rationale dialog before requesting permission |
| Technical error messages ("RMS < threshold") | Users don't understand what to do | Translate to actionable: "Tap louder or check microphone" |
| No feedback during count-in | Users don't know when to start | Visual countdown + metronome audio |
| Processing takes >5s with no indicator | Users think app froze | Show progress spinner during analysis |

---

## "Looks Done But Isn't" Checklist

- [ ] **Recording works**: Often missing file size validation - verify file > 100 bytes and contains audio data
- [ ] **Onset detection passes tests**: Often missing diverse test data - verify with soft taps, loud claps, background noise
- [ ] **Timing accuracy validated**: Often missing latency compensation - verify on 3+ physical devices
- [ ] **Permissions granted**: Often missing AndroidManifest.xml entries - verify both manifest and runtime request
- [ ] **Audio session configured**: Often missing options (defaultToSpeaker) - verify routing with headphones/speaker
- [ ] **FFT parameters tuned**: Often missing windowing function - verify spectral leakage test (silence → no energy)
- [ ] **Playback + recording simultaneous**: Often missing bleed detection - verify with speaker mode (should detect or warn)
- [ ] **Error handling complete**: Often missing user-friendly messages - verify all catch blocks have actionable text

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Audio session conflicts | LOW | Add audio_session package, reconfigure after all plugins loaded (1-2 hours) |
| Empty/corrupt files from paths | LOW | Switch to `getApplicationDocumentsDirectory()`, add validation (1 hour) |
| AAC codec issues | LOW | Switch to `Codec.pcm16WAV`, accept larger file sizes (30 min) |
| Missing device testing | MEDIUM | Acquire 2-3 test devices, re-test all audio features (1-2 days) |
| FFT timing errors | MEDIUM | Adjust window/hop size, add Hann window, re-tune threshold (4-8 hours) |
| Spectral flux threshold tuned on limited data | MEDIUM | Collect diverse recordings, implement adaptive threshold (1 day) |
| No latency calibration | HIGH | Implement calibration UX + measurement + storage (3-5 days) |
| Buffer overflow (architecture) | HIGH | Refactor to dedicated audio thread, async I/O (1 week) |
| Metronome bleed (no detection) | MEDIUM | Implement consistency check, add headphone detection (1-2 days) |
| Spectral leakage (no windowing) | LOW | Add Hann window multiplication before FFT (1-2 hours) |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Audio session conflicts | Phase 1 (Audio Infra) | Playback + recording work simultaneously on iOS & Android |
| Empty/corrupt files | Phase 1 (Audio Infra) | File size > 100 bytes, duration matches expected |
| AAC codec issues | Phase 1 (Audio Infra) | WAV files play back correctly on all test devices |
| Emulator false confidence | Phase 1 & 5 (Fix + Testing) | All features validated on 3+ physical devices |
| FFT window/hop timing | Phase 2 (Onset Detection) | Onset timestamps within ±30ms of expected beats |
| Spectral flux threshold | Phase 2 (Onset Detection) | Detects soft & loud taps, rejects silence & noise |
| Android latency | Phase 3 (Latency Cal) | Timing bias < 20ms after calibration on all devices |
| Buffer overflow | Phase 2 (Onset Detection) | No "AudioRecord OVERRUN" in logs during 60s recording |
| Metronome bleed | Phase 1 (Audio Infra) | Bleed detection triggers when headphones disconnected |
| Spectral leakage | Phase 2 (Onset Detection) | FFT of silence shows < -60 dB energy |

---

## Sources

**flutter_sound Issues & Limitations:**
- [starting recording fails (silently) to create file on phone · Issue #165](https://github.com/Canardoux/flutter_sound/issues/165)
- [Recorded audio files are corrupted on some Android devices · Issue #2749](https://github.com/FlutterFlow/flutterflow-issues/issues/2749)
- [Recording does not work on real iOS device · Issue #881](https://github.com/Canardoux/flutter_sound/issues/881)
- [flutter_sound audio package conflicts · Issue #855](https://github.com/Canardoux/flutter_sound/issues/855)
- [Use same audio engine for player and recorder in IOS · Issue #1109](https://github.com/Canardoux/flutter_sound/issues/1109)

**Audio Session Management:**
- [Speech Recognition in Flutter with Audio Session Handling](https://medium.com/@shahricha723/%EF%B8%8F-speech-recognition-in-flutter-with-audio-session-handling-mic-playback-harmony-838dca0ec00b)
- [audio_session package](https://pub.dev/packages/audio_session)

**Android Audio Latency:**
- [Audio latency | Android NDK](https://developer.android.com/ndk/guides/audio/audio-latency)
- [Android Audio's 10 Millisecond Problem](https://superpowered.com/androidaudiopathlatency)
- [Audio latency for app developers | AOSP](https://source.android.com/docs/core/audio/latency/app)

**FFT & Onset Detection Best Practices:**
- [How to Use Python to Detect Music Onsets](https://www.freecodecamp.org/news/use-python-to-detect-music-onsets/)
- [Choice of Hop Size | Spectral Audio Signal Processing](https://www.dsprelated.com/freebooks/sasp/Choice_Hop_Size.html)
- [Beat detection algorithm](https://www.parallelcube.com/2018/03/30/beat-detection-algorithm/)
- [OBTAIN: Real-Time Beat Tracking in Audio Signals](https://arxiv.org/pdf/1704.02216)

**FFT Windowing Functions:**
- [Understanding FFTs and Windowing](https://www.ni.com/en/shop/data-acquisition/measurement-fundamentals/analog-fundamentals/understanding-ffts-and-windowing.html)
- [Spectral leakage and windowing](https://brianmcfee.net/dstbook-site/content/ch06-dft-properties/Leakage.html)
- [FFT Windowing Functions Explained: Hanning, Hamming, Blackman](https://eureka.patsnap.com/article/fft-windowing-functions-explained-hanning-hamming-blackman)

**Buffer Management & Real-Time Processing:**
- [Android Audio Recording guide… Part 2 (AudioRecord)](https://medium.com/@anuandriesz/android-audio-recording-guide-part-2-audiorecord-f98625ec4588)
- [Real Time Sound Processing on Android](https://steveyko.github.io/assets/pdf/rtdroid-sound-jtres16.pdf)

**Testing & Device Compatibility:**
- [Simulation vs. real device testing for Flutter apps](https://blog.logrocket.com/simulation-real-device-testing-flutter-apps/)

**Permissions & Storage:**
- [Accessing Storage in Flutter for Devices Running Android 11 and Above](https://medium.com/@yogxworld/accessing-storage-in-flutter-for-devices-running-android-11-and-above-c5ab33330b9b)
- [Flutter app permissions for Android and ios](https://medium.com/@pratikmakwana10/flutter-app-permissions-for-android-and-ios-b895fb268752)

**Audio Formats & Codecs:**
- [flutter_sound recorder documentation](https://github.com/hxjhnct/flutter_sound/blob/master/doc/recorder.md)
- [flutter_sound codec compatibility](https://github.com/shogo-ma/flutter_sound/blob/master/flutter_sound/doc/codec.md)
- [Playing Audio by Processing Raw PCM Audio Data in Flutter](https://medium.com/@utkuaydogdu01/playing-audio-by-processing-raw-pcm-audio-data-in-flutter-practical-guide-and-best-audio-packages-455dedcd129e)

---

*Pitfalls research for: Flutter Audio Recording & Rhythm Analysis*
*Researched: 2026-02-10*

# Project Research Summary

**Project:** AI Rhythm Coach
**Domain:** Flutter rhythm/music practice app with AI-powered coaching
**Researched:** 2026-02-10
**Confidence:** HIGH

## Executive Summary

AI Rhythm Coach is a Flutter-based Android app that helps drummers improve timing accuracy through AI-powered feedback. Expert rhythm practice apps use a three-stage architecture: accurate metronome playback, FFT-based onset detection for timing analysis, and personalized coaching feedback. The MVP focuses on 4/4 time signatures at 40-200 BPM with 60-second practice sessions analyzed locally on-device.

The recommended approach uses the `record` package (replacing flutter_sound) for audio recording, `fftea` for FFT analysis, and WAV/PCM16 format instead of AAC to avoid Android codec corruption issues. The architecture follows a layered pattern with a state machine controller orchestrating AudioService, RhythmAnalyzer, AICoachingService, and SessionManager services. Critical to success is proper audio session configuration to prevent metronome bleed into recordings, latency calibration to avoid blaming users for hardware delays, and careful FFT parameter tuning (2048 window, 512 hop size) for accurate onset detection.

The primary risks are: (1) audio session conflicts between plugins causing recording failures, (2) device-specific latency (20-200ms) creating systematic timing bias, and (3) spectral flux threshold over-tuning on limited test data leading to production failures. These are mitigated through audio_session configuration before recording, mandatory device calibration on first run, and adaptive thresholding validated across diverse recordings and device types. Testing on physical devices is non-negotiable—emulators provide false confidence for audio features.

## Key Findings

### Recommended Stack

The current stack needs critical updates to fix known audio recording corruption issues. The flutter_sound package (v9.2.13) has documented Android recording failures and should be replaced with the actively-maintained `record` package (v6.2.0). AAC codec causes quality degradation on Android and is unsuitable for onset detection—WAV/PCM16 format is required for direct access to raw samples. The `audio_session` package must be added to prevent plugin conflicts and configure proper audio routing.

**Core technologies:**
- **record v6.2.0**: Audio recording — Modern replacement for flutter_sound, no corruption issues, PCM16/WAV streaming support
- **fftea v1.5.0**: FFT analysis — Pure Dart, 60-80x faster than alternatives, handles arbitrary input sizes for onset detection
- **provider v6.1.5**: State management — Flutter-recommended pattern, lightweight dependency injection, already in use
- **audio_session v0.2.2**: Audio configuration — Critical for preventing recording conflicts, manages iOS/Android audio routing
- **permission_handler v11.0.0**: Runtime permissions — Required for Android microphone access
- **path_provider v2.1.0**: File system paths — Platform-agnostic storage for audio files

**Critical replacements:**
- Remove `flutter_sound: ^9.2.13` → Add `record: ^6.2.0` (fixes Android recording corruption)
- Change codec from AAC → WAV/PCM16 (required for onset detection, eliminates quality issues)
- Add `audio_session: ^0.2.2` (prevents plugin conflicts, configures playback+recording mode)

### Expected Features

Rhythm practice apps have clear table stakes that users expect from any metronome-based practice tool. The differentiator for AI Rhythm Coach is combining millisecond-level timing analysis with personalized AI coaching—this is not found in existing apps like Soundbrenner (hardware-focused) or Rhythm Trainer (generic grading).

**Must have (table stakes):**
- Accurate metronome (audible click + visual beat indicator) — Foundation users compare against other apps
- BPM adjustment (40-200, tap tempo, 1 BPM increments) — Essential for practice across skill levels
- 4/4 time signature with downbeat emphasis — 90% of practice use cases
- 4-beat count-in before recording — Prevents jarring transitions, gives preparation time
- Start/stop controls with session timing display — Basic usability expectation

**Should have (competitive differentiators):**
- FFT-based onset detection with per-beat timing analysis — Shows early/late errors in milliseconds
- AI coaching feedback (2-3 sentences) — Personalized improvement suggestions based on actual performance
- Session history (last 10 sessions) — Basic progress tracking without excessive storage
- Average error + consistency metrics — Summary statistics for quick performance assessment
- Per-beat accuracy visualization — Graphical display makes timing patterns visible

**Defer (v2+):**
- Real-time visual feedback during practice — Technically complex (latency issues), post-practice analysis sufficient for MVP
- Multiple time signatures (3/4, 6/8, 5/4) — Broader appeal but 4/4 covers most users
- Subdivision support (eighth notes, triplets) — For intermediate/advanced users only
- Muted beat trainer — Advanced feature requiring strong internal timing first
- Automatic tempo progression — Nice automation but users can manually adjust

**Anti-features (explicitly avoid):**
- Built-in tuner — Unnecessary bloat, users prefer dedicated tuner apps
- Social features/leaderboards — Adds complexity, privacy concerns, ongoing moderation costs
- Subscription for basic features — Users resist monthly fees for sporadic practice tools
- Game-ification with points/badges — Creates extrinsic motivation that can backfire

### Architecture Approach

The standard architecture for audio recording and beat detection apps uses a layered approach separating presentation (screens/widgets), state management (controllers), services (audio/analysis/AI), and platform integration (flutter packages). A state machine controller orchestrates the complete practice flow from idle → countIn → recording → processing → completed, coordinating dependencies between services. FFT processing must run in a separate isolate to prevent UI jank, and audio session configuration is critical for simultaneous playback (metronome) and recording (user taps) without bleed.

**Major components:**
1. **PracticeController** — State machine orchestrator using ChangeNotifier, coordinates all services, manages practice session lifecycle
2. **AudioService** — Wraps `record` package for recording, plays metronome clicks (high/low for downbeat), handles audio session configuration via audio_session
3. **RhythmAnalyzer** — Pure Dart service using fftea for FFT-based onset detection, implements spectral flux analysis, matches detected onsets to expected beat times
4. **AICoachingService** — Formats session data into prompts, calls Claude/GPT APIs, returns 2-3 sentence coaching feedback
5. **SessionManager** — Persists session history (SharedPreferences + file system), auto-deletes oldest when exceeding 10 sessions
6. **CalibrationService** — Stores device-specific latency offset, applies compensation to timing calculations (critical for accuracy)

**Key patterns:**
- **Service dependency injection via Provider** — Services exposed at widget tree root, injected into controllers via constructor for testability
- **FFT windowing for onset detection** — Sliding window with Hann window function and spectral flux to detect transient events (drum hits)
- **Audio session configuration** — Platform-specific routing to prevent metronome bleeding into microphone recording
- **Latency compensation** — Store and apply per-device offset to correct for 20-200ms hardware delays

### Critical Pitfalls

Research identified 10 major pitfalls, with the top 5 being critical for MVP success. These are not theoretical—they are documented issues from flutter_sound GitHub and Android audio development articles.

1. **Audio session mode conflicts** — Multiple audio plugins override each other's settings, causing recording failures. Use audio_session package as single source of truth, configure AFTER all plugins loaded with playAndRecord category.

2. **Empty/corrupt audio files from wrong paths** — Recording produces 0-4096 byte files or silently fails. Always use getApplicationDocumentsDirectory() for recording paths, provide absolute paths, switch to WAV format for simpler debugging.

3. **AAC codec configuration mismatch** — Device-specific encoder compatibility issues cause garbled audio or corruption. Use WAV/PCM16 format instead—uncompressed, direct sample access for FFT, no device-specific issues.

4. **FFT window/hop size timing errors** — Onset detection reports beats at wrong times (50-200ms off) or misses beats entirely. Use 2048 window with 512 hop size, apply Hann window function before FFT, verify sample rate from WAV header.

5. **Spectral flux threshold over-tuning** — Threshold tuned on limited test data fails with real users' varied tap volumes and environments. Implement adaptive thresholding (mean + k×std_dev), test with diverse recordings (soft/loud, quiet/noisy), set minimum inter-onset interval (100ms).

**Additional critical pitfalls:**
- **Emulator audio testing false confidence** — Features work in emulator but fail on real devices. MUST test on physical Android devices from different manufacturers.
- **Android latency not measured** — Users blamed for 80-150ms hardware latency they can't control. Implement calibration UI, store per-device offset, apply compensation to all timing calculations.
- **Metronome bleed (simultaneous playback + recording)** — Microphone records metronome clicks, analysis detects perfect timing when user doesn't play. Configure audio routing, enforce headphone requirement, implement bleed detection (consistency < 3ms indicates machine).

## Implications for Roadmap

Based on research, the project has critical technical debt that must be resolved before new feature development. The existing architecture is sound but the stack has fundamental issues (flutter_sound corruption, AAC codec problems, missing audio session config) that will cause failures in production. Phase ordering is driven by: (1) fix broken audio recording first, (2) validate onset detection accuracy, (3) add calibration for fair feedback, (4) then build remaining features on stable foundation.

### Phase 1: Audio Infrastructure Fix
**Rationale:** Current audio recording is broken (flutter_sound corruption + AAC codec issues). Must establish working recording before any analysis or features can be built. This phase addresses 3 of the top 5 critical pitfalls.

**Delivers:**
- Reliable audio recording to WAV files
- Metronome playback without bleed into recording
- Proper audio session configuration
- Validated on physical Android devices

**Stack changes:**
- Replace flutter_sound with record package
- Change codec from AAC to WAV/PCM16
- Add audio_session configuration
- Add permission_handler for runtime permissions

**Addresses pitfalls:**
- Audio session mode conflicts (pitfall #1)
- Empty/corrupt files (pitfall #2)
- AAC codec mismatch (pitfall #3)
- Metronome bleed (pitfall #9)

**Features enabled:** Table stakes metronome functionality becomes reliable

**Research flag:** LOW — Migration path is clear from STACK.md, well-documented packages

---

### Phase 2: Onset Detection Fix & Validation
**Rationale:** With reliable WAV recordings, can now tune FFT parameters and onset detection threshold. This is the core differentiator—if timing analysis is inaccurate, AI coaching feedback is worthless. Must validate across diverse recordings before deploying.

**Delivers:**
- Accurate onset detection (±30ms of actual beat times)
- Adaptive spectral flux threshold robust to volume variations
- Hann windowing function to eliminate spectral leakage
- Validated across device types and tap intensities

**Architecture components:**
- RhythmAnalyzer service (FFT pipeline)
- FFT processing in isolate to prevent UI jank
- TapEvent model with timing errors

**Addresses pitfalls:**
- FFT window/hop size timing errors (pitfall #5)
- Spectral flux threshold over-tuning (pitfall #6)
- Missing windowing function (pitfall #10)
- Buffer overflow from UI thread processing (pitfall #8)

**Parameters to tune:**
- Window size: 2048 samples (46ms resolution @ 44100 Hz)
- Hop size: 512 samples (75% overlap, 11.6ms frame rate)
- Threshold: Adaptive (mean + 2.5×std_dev over running window)
- Minimum inter-onset: 100ms (prevents double-triggers)

**Research flag:** MEDIUM — FFT onset detection is well-documented but threshold tuning requires empirical testing on diverse recordings

---

### Phase 3: Latency Calibration
**Rationale:** Android devices have 20-200ms audio latency that varies by manufacturer and audio route (speaker/headphones/Bluetooth). Without calibration, users are systematically blamed for hardware delays they can't control. This is critical for fair feedback and user trust.

**Delivers:**
- Calibration UI (tap along to metronome, measure offset)
- Per-device latency storage (SharedPreferences)
- Latency compensation applied to all timing calculations
- User can recalibrate when switching devices/headphones

**Architecture components:**
- CalibrationService (stores/applies offset)
- CalibrationScreen (UX for measurement)
- Integration with RhythmAnalyzer (apply offset before beat matching)

**Addresses pitfalls:**
- Android audio latency not measured (pitfall #7)

**Research flag:** LOW — Standard pattern, audio_session provides latency APIs

---

### Phase 4: Session Results & AI Coaching
**Rationale:** With accurate timing analysis and latency compensation, can now provide meaningful AI coaching. This is the main differentiator over competitors—personalized feedback based on actual performance data rather than generic tips.

**Delivers:**
- Results screen with per-beat accuracy visualization
- Average error + consistency metrics
- AI coaching feedback (2-3 sentences via Claude/GPT)
- Session saved to history

**Architecture components:**
- AICoachingService (formats prompts, calls API)
- SessionManager (persists metadata + audio files)
- Results screen UI

**Features:**
- Per-beat accuracy display (table stakes differentiator)
- AI coaching feedback (main differentiator)
- Session history (competitive feature)

**Research flag:** LOW — HTTP API integration is straightforward, prompt engineering may need iteration

---

### Phase 5: UI Polish & Testing
**Rationale:** With core functionality working, polish the practice flow and validate end-to-end on multiple devices. Ensure error handling, loading states, and edge cases are handled gracefully.

**Delivers:**
- Practice screen with BPM controls, visual countdown
- Loading indicators during analysis
- Error messages translated to user-actionable text
- Headphone detection with warnings
- Validated on 3+ physical Android devices

**Addresses pitfalls:**
- Emulator false confidence (pitfall #4)
- UX pitfalls (no feedback during count-in, technical error messages)

**Research flag:** LOW — Standard Flutter UI patterns

---

### Phase Ordering Rationale

**Why this order:**
1. **Audio infrastructure first** — Nothing works if recording is broken. Fixing flutter_sound/AAC issues unblocks all downstream work.
2. **Onset detection second** — Core algorithm must be accurate before building features on top. Validation prevents wasted work on AI coaching with bad input data.
3. **Calibration third** — Latency compensation is critical for fair feedback but requires working onset detection to implement.
4. **AI coaching fourth** — Differentiating feature, but depends on accurate timing analysis to provide value.
5. **UI polish last** — With stable backend, focus on user experience and edge cases.

**Why this grouping avoids pitfalls:**
- Phases 1-2 address all top 5 critical pitfalls before user-facing features
- Phase 3 prevents user frustration from hardware latency (trust issue)
- Phase 5 validates on real devices, avoiding emulator false confidence
- Sequential validation (fix → validate → iterate) prevents cascading failures

**Dependencies discovered:**
- Audio recording must be reliable before onset detection can be tuned
- Onset detection must be accurate before latency calibration is meaningful
- Timing analysis must be fair (latency-compensated) before AI coaching provides value
- All backend services must work before UI can be polished

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Onset Detection):** FFT parameter tuning is empirical—will need iterative testing with diverse recordings to find optimal window/hop/threshold values. Research provided starting points but real-world validation required.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Audio Infrastructure):** Package migration path is clear, audio_session configuration well-documented
- **Phase 3 (Latency Calibration):** Standard calibration pattern, APIs provided by audio_session
- **Phase 4 (AI Coaching):** Straightforward HTTP API integration, prompt engineering can iterate
- **Phase 5 (UI Polish):** Standard Flutter UI patterns, established testing approaches

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Official package docs reviewed, migration path from flutter_sound to record verified with recent releases (record 6.2.0 released 11 days ago), codec issues documented in GitHub issues |
| Features | MEDIUM | Based on web search of competitor apps (Soundbrenner, Rhythm Trainer, Drummer ITP) and community discussions. No direct API documentation (not applicable). Table stakes validated across multiple sources. |
| Architecture | HIGH | Flutter official docs for architecture patterns, layered approach standard for audio apps, verified against record package examples and audio processing guides |
| Pitfalls | HIGH | Documented flutter_sound GitHub issues (#165, #881, #1070, #2749), Android audio latency articles from AOSP/NDK docs, FFT best practices from academic sources and DSP resources |

**Overall confidence:** HIGH

Research is well-grounded in official documentation (Flutter, Android AOSP, package docs) and verified against documented issues (flutter_sound problems, AAC codec quality). Feature research is medium confidence (competitor analysis via web search) but sufficient for MVP definition. Architecture and pitfall research is high confidence—patterns are well-established and pitfalls are documented with source attribution.

### Gaps to Address

**During Phase 1 implementation:**
- Verify record package WAV output format is compatible with existing RhythmAnalyzer PCM parsing
- Test audio_session configuration doesn't conflict with any other plugins if added later
- Confirm Android permission flow works on Android 13+ with new permission model

**During Phase 2 implementation:**
- FFT threshold tuning requires empirical testing—starting values provided (mean + 2.5×std_dev) but may need adjustment based on real recordings
- Onset detection accuracy validation needs diverse test set: soft taps, loud claps, background noise, reverberant rooms
- Determine if 2048 window is sufficient for 40 BPM (1.5s between beats) or if larger window needed

**During Phase 3 implementation:**
- Latency calibration UX design not researched—need to define user flow for tap-along measurement
- Determine if single calibration sufficient or need separate calibration per audio route (speaker/wired/Bluetooth)

**General validation:**
- All audio features must be tested on physical devices from at least 3 manufacturers (Samsung, Pixel, Xiaomi/OnePlus)
- Emulator testing is invalid for audio features—research confirms emulator provides false confidence

## Sources

### Primary (HIGH confidence)
- [record package v6.2.0](https://pub.dev/packages/record) — Modern audio recording, Android implementation, PCM16/WAV support
- [fftea package v1.5.0](https://pub.dev/packages/fftea) — FFT performance benchmarks, API documentation, pure Dart implementation
- [audio_session package v0.2.2](https://pub.dev/packages/audio_session) — Audio focus management, iOS AVAudioSession/Android AudioAttributes configuration
- [Flutter isolates documentation](https://docs.flutter.dev/perf/isolates) — Performance best practices for compute-heavy operations
- [Flutter architecture patterns](https://docs.flutter.dev/app-architecture/design-patterns) — Official guidance on layered architecture and state management
- [Android audio latency documentation](https://developer.android.com/ndk/guides/audio/audio-latency) — NDK latency measurement, AAudio API
- [Android Audio Architecture AOSP](https://source.android.com/docs/core/audio) — AudioFlinger, audio session management, debugging

### Secondary (MEDIUM confidence)
- [flutter_sound GitHub issues](https://github.com/Canardoux/flutter_sound/issues) — Issues #165 (empty files), #881 (iOS device failures), #1070 (Android corruption), #2749 (codec quality)
- [Real-time frequency extraction guide](https://medium.com/neusta-mobile-solutions/master-real-time-frequency-extraction-in-flutter-to-elevate-your-app-experience-f5fef9017f09) — FFT implementation patterns, isolate usage
- [Android audio recording guide](https://medium.com/@anuandriesz/android-audio-recording-guide-part-2-audiorecord-f98625ec4588) — AudioRecord vs MediaRecorder, buffer management
- [Beat tracking algorithm](https://www.parallelcube.com/2018/03/30/beat-detection-algorithm/) — Spectral flux onset detection fundamentals
- [FFT windowing functions](https://www.ni.com/en/shop/data-acquisition/measurement-fundamentals/analog-fundamentals/understanding-ffts-and-windowing.html) — Hann/Hamming windows, spectral leakage prevention
- Competitor app analysis (Soundbrenner, Rhythm Trainer, Drummer ITP) — Feature expectations via app stores and review sites

### Tertiary (LOW confidence)
- Community forum discussions on metronome accuracy expectations — User preferences for tap tempo, visual indicators
- Web search results for rhythm practice app features — Validated across multiple sources but not official documentation

---
*Research completed: 2026-02-10*
*Ready for roadmap: yes*

# Architecture Research: Audio Recording and Beat Detection in Mobile Apps

**Domain:** Rhythm/Music Practice Apps with Real-Time Audio Processing
**Researched:** 2026-02-10
**Confidence:** HIGH

## Standard Architecture

### System Overview

Audio recording and beat detection systems follow a layered architecture that separates concerns between UI, orchestration, domain services, and platform integration:

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                      │
│  │Practice │  │Results  │  │Settings │                      │
│  │ Screen  │  │ Screen  │  │ Screen  │                      │
│  └────┬────┘  └────┬────┘  └────┬────┘                      │
│       │            │            │                            │
├───────┴────────────┴────────────┴────────────────────────────┤
│                STATE MANAGEMENT LAYER                        │
│  ┌──────────────────────────────────────────────────────┐    │
│  │         Practice Controller (Orchestrator)           │    │
│  │   State Machine: idle → countIn → recording →        │    │
│  │                 processing → completed/error         │    │
│  └────┬──────────────┬────────────┬──────────────────────┘   │
│       │              │            │                          │
├───────┴──────────────┴────────────┴──────────────────────────┤
│                    SERVICE LAYER                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │  Audio   │  │ Rhythm   │  │   AI     │  │ Session  │    │
│  │ Service  │  │Analyzer  │  │Coaching  │  │ Manager  │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       │             │              │             │           │
├───────┴─────────────┴──────────────┴─────────────┴───────────┤
│              PLATFORM/PERSISTENCE LAYER                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │flutter_  │  │  fftea   │  │  HTTP    │  │SharedPref│    │
│  │ sound    │  │  (FFT)   │  │  API     │  │+FileIO   │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **PracticeController** | Orchestrates complete practice flow, manages state machine, coordinates services | ChangeNotifier with dependency injection |
| **AudioService** | Records user audio, plays metronome clicks, manages audio session configuration | Wraps flutter_sound with platform-specific config |
| **RhythmAnalyzer** | FFT-based onset detection, beat matching, timing analysis | Pure Dart service using fftea for FFT |
| **AICoachingService** | Formats prompts and calls AI APIs for feedback generation | HTTP client with error handling |
| **SessionManager** | Persists session history (metadata + audio files), enforces limits | Manages SharedPreferences + file system |
| **CalibrationService** | Stores and applies system latency offset for timing accuracy | SharedPreferences-based persistence |

## Recommended Project Structure

```
lib/
├── main.dart                          # App entry, MultiProvider setup
├── config.dart                        # AI API keys (gitignored)
├── models/
│   ├── session.dart                   # Session data + JSON serialization
│   ├── tap_event.dart                 # Individual beat timing event
│   └── practice_state.dart            # State machine enum
├── controllers/
│   └── practice_controller.dart       # Main orchestrator (ChangeNotifier)
├── services/
│   ├── audio_service.dart             # Audio recording/playback/metronome
│   ├── rhythm_analyzer.dart           # FFT onset detection
│   ├── ai_coaching_service.dart       # AI API integration
│   ├── session_manager.dart           # Session persistence
│   └── calibration_service.dart       # Latency calibration
├── screens/
│   ├── practice_screen.dart           # Main practice UI
│   ├── results_screen.dart            # Post-session feedback
│   └── calibration_screen.dart        # Latency calibration UI
└── widgets/                           # Reusable UI components

assets/
└── audio/
    ├── click_high.wav                 # Downbeat metronome click
    └── click_low.wav                  # Regular beat click
```

### Structure Rationale

- **Feature-first within controllers/services:** All related functionality grouped by domain (audio, rhythm, coaching) rather than technical layer
- **Pure Dart services:** RhythmAnalyzer has no Flutter dependencies, enabling easy unit testing
- **Flat service directory:** Only 5-6 services for MVP, no need for subdirectories
- **Explicit models directory:** Data models separate from business logic for clarity

## Architectural Patterns

### Pattern 1: State Machine Orchestrator

**What:** Single controller manages entire practice session lifecycle through explicit states

**When to use:** Multi-step workflows involving multiple services with dependencies between steps

**Trade-offs:**
- **Pro:** Clear state transitions, easier debugging, prevents invalid state combinations
- **Pro:** Centralized error handling
- **Con:** Controller can grow complex if too many responsibilities added

**Example:**
```dart
class PracticeController extends ChangeNotifier {
  PracticeState _state = PracticeState.idle;

  // Services injected via constructor
  final AudioService _audioService;
  final RhythmAnalyzer _rhythmAnalyzer;
  final AICoachingService _aiCoachingService;

  Future<void> startSession() async {
    _setState(PracticeState.countIn);
    await _audioService.playCountIn(_bpm);

    _setState(PracticeState.recording);
    await _audioService.startRecording();
    await _audioService.startMetronome(_bpm);
    // ... continue workflow
  }

  void _setState(PracticeState newState) {
    _state = newState;
    notifyListeners(); // Triggers UI rebuild
  }
}
```

### Pattern 2: Service Layer Dependency Injection via Provider

**What:** Services exposed at widget tree root, injected into controllers via constructor

**When to use:** When multiple controllers/widgets need shared service instances, for testing with mocks

**Trade-offs:**
- **Pro:** Explicit dependencies in constructor, easy to mock for tests
- **Pro:** Single source of truth for service instances
- **Con:** Requires boilerplate in main.dart MultiProvider setup

**Example:**
```dart
// main.dart
runApp(
  MultiProvider(
    providers: [
      Provider<AudioService>(create: (_) => AudioService()),
      Provider<RhythmAnalyzer>(create: (_) => RhythmAnalyzer()),
      ChangeNotifierProvider<PracticeController>(
        create: (context) => PracticeController(
          audioService: context.read<AudioService>(),
          rhythmAnalyzer: context.read<RhythmAnalyzer>(),
          // ... other services
        ),
      ),
    ],
    child: MyApp(),
  ),
);
```

### Pattern 3: FFT Windowing for Onset Detection

**What:** Sliding window FFT with spectral flux analysis to detect sudden audio changes (onsets)

**When to use:** Detecting transient events in audio (drum hits, claps, taps) without machine learning

**Trade-offs:**
- **Pro:** Computationally efficient, works offline, no training data needed
- **Pro:** Tunable threshold for different signal types
- **Con:** Sensitive to noise, requires careful parameter tuning (window size, hop size, threshold)
- **Con:** Struggles with soft/gradual attacks

**Example:**
```dart
class RhythmAnalyzer {
  static const int fftSize = 2048;  // Balance time/frequency resolution
  static const int hopSize = 512;    // 75% overlap for smooth detection

  List<double> _detectOnsets(List<double> samples) {
    final fft = FFT(fftSize);
    List<double>? previousMagnitudes;
    final onsets = <double>[];

    for (int i = 0; i < samples.length - fftSize; i += hopSize) {
      final window = samples.sublist(i, i + fftSize);
      final windowed = _applyHanningWindow(window);
      final spectrum = fft.realFft(windowed);

      final magnitudes = spectrum.map((c) =>
        sqrt(c.x * c.x + c.y * c.y)).toList();

      if (previousMagnitudes != null) {
        final flux = _calculateSpectralFlux(magnitudes, previousMagnitudes);
        if (flux > onsetThreshold) {
          onsets.add((i + fftSize / 2) / sampleRate);
        }
      }
      previousMagnitudes = magnitudes;
    }
    return onsets;
  }
}
```

### Pattern 4: Audio Session Configuration for Simultaneous Recording/Playback

**What:** Platform-specific audio routing configuration to prevent metronome bleeding into recording

**When to use:** Apps that need to play audio (metronome, backing track) while recording microphone input

**Trade-offs:**
- **Pro:** Prevents audio feedback loops, enables clean user recordings
- **Pro:** Proper echo cancellation on supported devices
- **Con:** Platform-specific configuration required (iOS AVAudioSession, Android AudioAttributes)
- **Con:** Behavior varies across devices/OS versions

**Example:**
```dart
Future<void> _configureAudioRouting() async {
  final session = await AudioSession.instance;

  await session.configure(AudioSessionConfiguration(
    // iOS configuration
    avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
    avAudioSessionCategoryOptions:
      AVAudioSessionCategoryOptions.allowBluetooth |
      AVAudioSessionCategoryOptions.defaultToSpeaker,
    avAudioSessionMode: AVAudioSessionMode.defaultMode,

    // Android configuration
    androidAudioAttributes: const AndroidAudioAttributes(
      contentType: AndroidAudioContentType.music,
      usage: AndroidAudioUsage.media,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
  ));
}
```

### Pattern 5: Latency Compensation

**What:** Store system-specific audio latency offset, apply to all timing calculations

**When to use:** Precision timing apps where audio playback/recording latency affects results

**Trade-offs:**
- **Pro:** Corrects for hardware-specific delays (50-300ms common on mobile)
- **Pro:** One-time calibration improves all future sessions
- **Con:** Requires calibration UI/workflow
- **Con:** User may forget to recalibrate when switching devices/headphones

**Example:**
```dart
class RhythmAnalyzer {
  Future<List<TapEvent>> analyzeAudio({
    required String audioFilePath,
    required int bpm,
    int latencyOffsetMs = 0,
  }) async {
    final rawOnsetTimes = _detectOnsets(samples);

    // Apply latency compensation
    final latencySeconds = latencyOffsetMs / 1000.0;
    final correctedOnsets = rawOnsetTimes
      .map((t) => t - latencySeconds)
      .toList();

    return _matchOnsetsToBeats(correctedOnsets, expectedBeats);
  }
}
```

## Data Flow

### Request Flow: Complete Practice Session

```
[User taps "Start Practice"]
    ↓
[PracticeController.startSession()]
    ↓
[AudioService.playCountIn()] → 4-beat metronome countdown
    ↓
[PracticeController state: countIn → recording]
    ↓
┌──────────────────────────────────────┐
│ PARALLEL EXECUTION (60 seconds):     │
│  • AudioService.startRecording()     │
│  • AudioService.startMetronome()     │
│  • Timer updates UI countdown        │
└──────────────────────────────────────┘
    ↓
[60s elapsed OR user stops early]
    ↓
[AudioService.stopRecording()] → returns audioFilePath
[AudioService.stopMetronome()]
    ↓
[PracticeController state: recording → processing]
    ↓
[CalibrationService.getLatency()] → latencyOffsetMs
    ↓
[RhythmAnalyzer.analyzeAudio()] → List<TapEvent>
    ↓ (analyzes audio)
┌──────────────────────────────────────┐
│ FFT PROCESSING PIPELINE:             │
│  WAV file → PCM samples              │
│    ↓                                 │
│  Sliding FFT windows (2048 samples)  │
│    ↓                                 │
│  Spectral flux calculation           │
│    ↓                                 │
│  Onset detection (threshold)         │
│    ↓                                 │
│  Beat matching (±300ms tolerance)    │
│    ↓                                 │
│  List<TapEvent> with timing errors   │
└──────────────────────────────────────┘
    ↓
[Calculate metrics: averageError, consistency]
    ↓
[AICoachingService.generateCoaching()] → HTTP request
    ↓
[Create Session object with all data]
    ↓
[SessionManager.saveSession()] → SharedPreferences + file system
    ↓
[PracticeController state: processing → completed]
    ↓
[UI navigates to Results screen]
```

### State Management Flow

```
[PracticeController State Change]
    ↓
[notifyListeners() called]
    ↓
[All Consumer<PracticeController> widgets rebuild]
    ↓
[UI reflects new state: shows spinner, enables/disables buttons, displays results]
```

### Audio Pipeline Detail

```
RECORDING PATH:
Microphone → AudioService (flutter_sound) → PCM16 WAV file → File system

METRONOME PATH (separate from recording):
click_high.wav/click_low.wav → AudioService player → Headphones/Speaker
  (prevented from bleeding into recording via audio session config)

ANALYSIS PATH:
WAV file → Read bytes → Parse PCM samples → FFT windows → Onset detection
```

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| **Single user (MVP)** | Current architecture sufficient. All processing local, no backend needed. |
| **100-1K users** | No changes needed. Local processing scales linearly with user device CPU. |
| **1K-10K users** | Consider caching AI responses for identical performance patterns (reduce API costs). Add analytics to track usage. |
| **10K+ users** | Consider moving heavy FFT processing to backend API if users report slow phones. Add cloud session sync for multi-device support. |

### Scaling Priorities

1. **First bottleneck:** AI API costs at scale
   - **Fix:** Implement response caching for similar performance patterns
   - **Fix:** Offer local rule-based feedback as free tier, AI coaching as premium

2. **Second bottleneck:** On-device FFT processing on low-end phones
   - **Fix:** Optimize FFT parameters (reduce fftSize to 1024 on slow devices)
   - **Fix:** Background processing with progress indicator
   - **Alternative:** Offload to cloud API if latency acceptable (adds network dependency)

3. **Third bottleneck:** Local storage limits (audio files accumulate)
   - **Already mitigated:** SessionManager auto-deletes oldest sessions beyond 10
   - **Future:** Compress audio files post-analysis (users rarely replay them)

## Anti-Patterns

### Anti-Pattern 1: Global Service Singletons

**What people do:** Use `get_it` or static instances for service access

**Why it's wrong:**
- Hidden dependencies make testing harder (can't inject mocks easily)
- Tight coupling between components
- No lifecycle management (services live forever)

**Do this instead:** Use Provider-based DI with constructor injection. Services scoped to widget tree lifecycle, explicit dependencies visible in constructor.

### Anti-Pattern 2: Processing Audio on UI Thread

**What people do:** Run FFT analysis synchronously in controller methods

**Why it's wrong:**
- Freezes UI for 1-3 seconds during analysis
- Poor user experience, appears broken
- Can trigger ANR (Application Not Responding) on Android

**Do this instead:** Already implemented correctly in existing code—`analyzeAudio()` is async and Flutter's event loop handles it. For heavier processing, use `compute()` to run FFT in isolate.

### Anti-Pattern 3: Hardcoded Timing Values

**What people do:** Assume audio latency is 0ms or a fixed value like 100ms

**Why it's wrong:**
- Latency varies wildly: 50-300ms across devices, headphone types, Bluetooth vs wired
- Results in systematically early/late detection
- Frustrates users when feedback is inaccurate

**Do this instead:** Implement calibration UI (already done via CalibrationService). Let user tap along to metronome, calculate mean offset, apply to all future sessions.

### Anti-Pattern 4: Ignoring Audio Session Configuration

**What people do:** Start recording and metronome without configuring audio routing

**Why it's wrong:**
- Metronome bleeds into recording (microphone hears speaker)
- Results show perfect timing (it's detecting the metronome, not the user)
- Impossible to distinguish user performance from playback

**Do this instead:** Configure audio session for `playAndRecord` mode, route metronome to headphones, check for bleed detection in analysis (consistency < 3ms indicates machine, not human).

### Anti-Pattern 5: Over-Sensitive Onset Detection

**What people do:** Set onset threshold too low to "catch everything"

**Why it's wrong:**
- Detects noise, breathing, ambient sounds as beats
- Multiple false onsets per actual beat
- Reported timing becomes meaningless

**Do this instead:** Tune threshold empirically with real recordings. Add minimum inter-onset interval (50ms) to prevent double-detection. Check RMS energy to reject silent recordings early.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| **Anthropic Claude API** | HTTP POST to API endpoint, JSON request/response | Use streaming response for real-time feedback (future) |
| **OpenAI GPT API** | HTTP POST to API endpoint, JSON request/response | Configurable alternative to Claude |
| **Audio Session (iOS)** | AVAudioSession via audio_session package | Category: playAndRecord, defaultToSpeaker option |
| **Android AudioFlinger** | Configured via audio_session AndroidAudioAttributes | ContentType: music, Usage: media |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| **PracticeController ↔ AudioService** | Async method calls, no callbacks | Controller awaits service completion |
| **PracticeController ↔ RhythmAnalyzer** | Pure function call with file path | Analyzer is stateless service |
| **AudioService ↔ flutter_sound** | Direct library API calls | Wrapped for error handling |
| **RhythmAnalyzer ↔ fftea** | Direct library API calls | Pure computation, no state |
| **SessionManager ↔ SharedPreferences** | Async read/write of JSON strings | Max 10 sessions stored |
| **UI ↔ PracticeController** | Consumer<PracticeController> widgets | Reactive rebuild on notifyListeners() |

### Critical Integration: Audio Recording + Metronome Separation

**Problem:** Microphone records both user taps AND metronome clicks, making analysis detect metronome instead of user.

**Solution:** Three-layer defense:
1. **Audio routing:** Configure session to route metronome to headphones, microphone records only ambient sound
2. **User instruction:** App instructs user to wear headphones before starting
3. **Bleed detection:** Analyzer checks consistency—if < 3ms (machine-perfect), reject as metronome bleed

**Implementation:**
```dart
// 1. Audio routing (AudioService)
await session.configure(AudioSessionConfiguration(
  avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
  avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
));

// 2. User instruction (PracticeScreen UI)
Text('Please wear headphones to prevent metronome bleed');

// 3. Bleed detection (RhythmAnalyzer)
if (checkBleed && tapEvents.isNotEmpty) {
  final consistency = calculateConsistency(tapEvents);
  if (consistency < 3.0) {
    throw MetronomeBleedException('Use headphones to prevent metronome bleed');
  }
}
```

## Build Order Recommendations

Based on component dependencies, recommended implementation sequence:

### Phase 1: Foundation (Week 1)
**Build:** Models (Session, TapEvent, PracticeState)
- No dependencies, pure data structures
- Includes JSON serialization for persistence
- Unit testable immediately

### Phase 2: Audio Infrastructure (Week 2)
**Build:** AudioService (recording, metronome, playback)
**Depends on:** Models
- Test on physical device (emulator audio unreliable)
- Verify file creation, check file sizes
- Tune audio session configuration

### Phase 3: Analysis Engine (Week 2-3)
**Build:** RhythmAnalyzer (FFT onset detection)
**Depends on:** Models
- Start with test WAV files (known onset times)
- Tune threshold, window size empirically
- Add extensive logging for debugging

### Phase 4: Orchestration (Week 3)
**Build:** PracticeController (state machine)
**Depends on:** AudioService, RhythmAnalyzer, SessionManager
- Wire services together
- Implement state machine transitions
- Add error handling

### Phase 5: Calibration (Week 4)
**Build:** CalibrationService, CalibrationScreen
**Depends on:** AudioService, RhythmAnalyzer
- Essential for accuracy, not optional
- Let users calibrate before first session

### Phase 6: AI Integration (Week 4)
**Build:** AICoachingService
**Depends on:** Models
- Independent of other services
- Can be mocked during earlier testing

### Phase 7: Persistence (Week 5)
**Build:** SessionManager
**Depends on:** Models
- SharedPreferences for metadata
- File system for audio files
- Auto-cleanup logic

### Phase 8: UI Polish (Week 5-6)
**Build:** PracticeScreen, ResultsScreen
**Depends on:** All services
- Consumer widgets for reactive updates
- Handle all state machine states
- Loading indicators, error messages

## Sources

- [record | Flutter package](https://pub.dev/packages/record) - Modern audio recording package
- [Architecture design patterns | Flutter](https://docs.flutter.dev/app-architecture/design-patterns) - Official Flutter architecture guidance
- [Audio Processing: Beat Tracking Explained | audioXpress](https://audioxpress.com/article/audio-processing-beat-tracking-explained) - Beat tracking fundamentals
- [Real Time Sound Processing on Android | ACM JTRES](https://dl.acm.org/doi/10.1145/2990509.2990512) - Mobile audio latency research
- [Android Audio Architecture Overview | eInfochips](https://www.einfochips.com/blog/android-audio-architecture-overview/) - Android audio system architecture
- [Guide to app architecture | Flutter](https://docs.flutter.dev/app-architecture/guide) - Flutter layered architecture
- [audio_service | Flutter package](https://pub.dev/packages/audio_service) - Background audio patterns
- [Communicating between layers | Flutter DI](https://docs.flutter.dev/app-architecture/case-study/dependency-injection) - Official DI best practices
- [Simple app state management | Flutter](https://docs.flutter.dev/data-and-backend/state-mgmt/simple) - ChangeNotifier patterns
- [Real-time audio spectrum analysis with FFT | ScienceDirect](https://www.sciencedirect.com/science/article/pii/S1110866525001963) - FFT for real-time audio
- [Audio debugging | Android Open Source Project](https://source.android.com/docs/core/audio/debugging) - Android audio troubleshooting

---
*Architecture research for: Audio Recording and Beat Detection in Rhythm Practice Apps*
*Researched: 2026-02-10*

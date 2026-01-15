# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI Rhythm Coach is an Android mobile app that helps drummers and musicians improve rhythm accuracy through AI-powered coaching feedback. Users practice against a metronome, and the app analyzes their performance using onset detection algorithms and provides personalized coaching via Claude or GPT APIs.

**Current Status:** Active development - Core audio recording and onset detection implemented with native Android AudioRecord API.

**Platform:** Android (Flutter framework)
**MVP Scope:** 4/4 time signature, 40-200 BPM, 60-second practice sessions, local storage only

**Active Branches:**
- `main` - Stable baseline
- `fix/improve-onset-detection` - Onset detection improvements
- `feature/native-audio-record` - **Current work**: Native Android AudioRecord implementation for AGC control

**Session Logs:** See `CLAUDE_SESSION_LOG.md` for detailed development history and technical decisions

## Technology Stack

- **Framework:** Flutter/Dart
- **Audio Recording:** Native Android AudioRecord API (Kotlin) via platform channels
  - Direct hardware access with minimal AGC
  - VOICE_RECOGNITION audio source for optimal drum detection
  - 44.1kHz, Mono, PCM 16-bit WAV output
- **Audio Playback:** flutter_sound (metronome clicks)
- **DSP:** fftea (FFT for onset detection)
- **State Management:** Provider pattern
- **Persistence:** SharedPreferences (session metadata) + file system (audio files)
- **AI APIs:** Anthropic Claude or OpenAI GPT (configurable)
- **Key Dependencies:**
  - `provider: ^6.0.5` - State management
  - `flutter_sound: ^9.2.13` - Metronome playback only (recording uses native API)
  - `fftea: ^1.0.0` - FFT analysis
  - `http: ^1.1.0` - AI API calls
  - `shared_preferences: ^2.2.0` - Local storage
  - `path_provider: ^2.1.0` - File system paths
  - `uuid: ^4.0.0` - Session IDs

## Architecture

**Layered Architecture:**
1. **Presentation Layer:** Screens and widgets (UI)
2. **State Management Layer:** Controllers using Provider
3. **Service Layer:** AudioService, RhythmAnalyzer, AICoachingService
4. **Persistence Layer:** SessionManager (SharedPreferences + file system)

**Core Components:**

- **PracticeController** (`lib/controllers/practice_controller.dart`)
  - Orchestrates complete practice session lifecycle
  - State machine: idle → countIn → recording → processing → completed/error
  - Depends on: AudioService, RhythmAnalyzer, AICoachingService, SessionManager

- **SessionManager** (`lib/services/session_manager.dart`)
  - Manages persistence of session history (max 10 recent sessions)
  - Handles both metadata (SharedPreferences) and audio files (file system)
  - Auto-deletes oldest sessions when limit exceeded

- **AudioService** (`lib/services/audio_service.dart`)
  - **Recording:** Uses native Android AudioRecord API via NativeAudioRecorder
    - VOICE_RECOGNITION audio source (minimal AGC)
    - 44.1kHz sample rate, Mono, PCM 16-bit
    - Direct WAV file output (no AAC conversion needed)
  - **Playback:** Uses flutter_sound for metronome clicks
  - Plays metronome clicks (high/low for downbeat emphasis)
  - Plays 4-beat count-in before recording
  - Manages audio session configuration for proper headphone routing

- **NativeAudioRecorder** (`lib/services/native_audio_recorder.dart`)
  - Flutter wrapper for native Android AudioRecord
  - Platform channel communication with Kotlin implementation
  - Supports multiple audio sources (VOICE_RECOGNITION, UNPROCESSED, MIC)
  - Proper WAV header generation and file handling

- **RhythmAnalyzer** (`lib/services/rhythm_analyzer.dart`)
  - FFT-based onset detection (2048 sample window, 512 hop size)
  - Matches detected onsets to expected beat times (±300ms tolerance)
  - Calculates timing errors (actual - expected in milliseconds)
  - Returns List<TapEvent> with per-beat accuracy

- **AICoachingService** (`lib/services/ai_coaching_service.dart`)
  - Formats session data into structured AI prompt
  - Calls configured AI API (Claude or GPT)
  - Returns 2-3 sentence coaching feedback focusing on strengths + improvement areas

**Data Models:**

- **Session** (`lib/models/session.dart`)
  - id (UUID), timestamp, bpm, durationSeconds (60)
  - audioFilePath, tapEvents, averageError, consistency
  - coachingText (AI-generated)
  - JSON serialization for SharedPreferences

- **TapEvent** (`lib/models/tap_event.dart`)
  - actualTime, expectedTime, error (in milliseconds)
  - Helper properties: isEarly, isLate, isOnTime (±10ms tolerance)

- **PracticeState** (enum)
  - idle, countIn, recording, processing, completed, error

## Project Structure

```
lib/
├── main.dart                    # App entry point with MultiProvider setup
├── config.dart                  # AI API configuration (gitignored)
├── models/
│   ├── session.dart            # Session data model
│   └── tap_event.dart          # TapEvent data model
├── controllers/
│   └── practice_controller.dart # Main practice session orchestrator
├── services/
│   ├── session_manager.dart    # Session persistence
│   ├── audio_service.dart      # Audio recording/playback orchestration
│   ├── native_audio_recorder.dart # Flutter wrapper for native Android AudioRecord
│   ├── rhythm_analyzer.dart    # FFT onset detection
│   └── ai_coaching_service.dart # AI API integration
├── screens/
│   ├── practice_screen.dart    # Main practice interface
│   └── results_screen.dart     # Session results display
└── widgets/                     # Reusable UI components

android/
└── app/src/main/kotlin/com/rhythmcoach/ai_rhythm_coach/
    ├── MainActivity.kt          # Flutter activity with platform channel setup
    └── NativeAudioRecorder.kt   # Native Android AudioRecord implementation

assets/
└── audio/
    ├── click_high.wav          # 800 Hz, 50ms (downbeat)
    └── click_low.wav           # 400 Hz, 50ms (other beats)

test/
├── models/                      # Model serialization tests
├── controllers/                 # Controller state tests
└── services/                    # Service unit tests (use mockito)

quick_start_experiment/          # Python diagnostic tools for audio analysis
├── analyze_drum_practice.py    # Aubio-based onset detection analysis
├── diagnose_false_positives.py # AGC and clipping detection
├── analyze_new_recordings.py   # Multi-recording comparison tool
└── venv/                        # Python 3.10 environment with audio libraries

CLAUDE_SESSION_LOG.md            # Detailed development history and decisions
```

## Development Commands

**Setup:**
```bash
flutter pub get                  # Install dependencies
```

**Run:**
```bash
flutter run                      # Run on connected Android device/emulator
flutter run -d <device_id>      # Run on specific device
```

**Build:**
```bash
flutter build apk               # Build release APK
flutter build apk --debug       # Build debug APK
flutter build appbundle         # Build Android App Bundle (for Play Store)
```

**Testing:**
```bash
flutter test                    # Run all tests
flutter test test/path/file_test.dart  # Run specific test file
flutter test --coverage         # Generate coverage report
```

**Code Quality:**
```bash
flutter analyze                 # Run static analysis
flutter format lib/             # Format code
```

**Development:**
```bash
flutter devices                 # List connected devices
flutter doctor                  # Check Flutter setup
flutter clean                   # Clean build artifacts
```

## Configuration

**AI API Setup:**

Create `lib/config.dart` (this file is gitignored):
```dart
enum AIProvider { anthropic, openai }

class AIConfig {
  static const AIProvider provider = AIProvider.anthropic;
  static const String anthropicApiKey = 'YOUR_ANTHROPIC_KEY';
  static const String openaiApiKey = 'YOUR_OPENAI_KEY';
}
```

**API Key Security:**
- Never commit `lib/config.dart` to version control
- Add to `.gitignore`: `lib/config.dart`
- For production, use environment variables or secure key storage

## Key Implementation Details

**Practice Session Flow:**
1. User sets BPM (40-200) and taps Start
2. PracticeController transitions to countIn state
3. AudioService plays 4-beat count-in
4. Simultaneous recording + metronome starts (60 seconds)
5. Audio saved to app documents directory
6. RhythmAnalyzer processes audio via FFT onset detection
7. AICoachingService generates personalized feedback
8. SessionManager saves session (metadata + audio file)
9. Results displayed to user

**Audio Processing Pipeline:**
```
Native AudioRecord (VOICE_RECOGNITION source)
→ Raw PCM 16-bit samples (44.1kHz, Mono)
→ WAV file with proper headers
→ FFT Windows (2048 samples, 512 hop)
→ Spectral Flux calculation
→ Onset Detection (threshold: 0.25)
→ Beat Matching (±300ms tolerance)
→ TapEvents with timing errors (ms)
```

**Storage Strategy:**
- **Session Metadata:** SharedPreferences (JSON array, max 10 sessions)
- **Audio Files:** App documents directory (WAV format, PCM 16-bit)
- **Auto-cleanup:** Oldest session deleted when limit exceeded
- **No cloud sync:** All data local-only for MVP

**State Management:**
- Provider pattern for dependency injection
- ChangeNotifier for reactive UI updates
- Controllers extend ChangeNotifier, call notifyListeners() on state changes

## Testing Strategy

**Unit Tests:**
- Data model serialization/deserialization
- PracticeController state transitions
- SessionManager CRUD operations (use mockito for SharedPreferences)
- RhythmAnalyzer onset detection accuracy

**Integration Tests:**
- Complete practice session flow (end-to-end)
- AudioService recording + metronome synchronization

**Manual Testing:**
- Must test on physical Android device (emulator has limited audio support)
- Verify metronome timing accuracy against external metronome app
- Test various BPMs (40, 80, 120, 160, 200)
- Test different tap intensities (loud, soft)

## Implementation Phases

**Phase 1:** Data Models & State Foundation (1 week)
- Implement Session, TapEvent models with JSON serialization
- Create PracticeController and SessionManager shells
- Setup Provider configuration in main.dart

**Phase 2:** Audio Services (2 weeks)
- Implement AudioService (recording, metronome, playback)
- Test on physical device for audio quality

**Phase 3:** Rhythm Analysis (2 weeks)
- Implement RhythmAnalyzer with FFT onset detection
- Tune threshold values through experimentation
- Validate accuracy with test audio files

**Phase 4:** AI Integration (1 week)
- Implement AICoachingService for Claude/GPT APIs
- Design effective coaching prompts
- Handle API errors gracefully

**Phase 5:** UI Implementation (3 weeks)
- Build PracticeScreen with BPM controls
- Build ResultsScreen with coaching display
- Session history list view

**Phase 6:** Testing & Polish (2 weeks)
- End-to-end testing
- Performance optimization
- Bug fixes and UI refinements

## Important Constraints

- **Solo developer:** Simplicity-first, avoid over-engineering
- **Flutter beginner:** Use straightforward patterns, avoid advanced Flutter techniques
- **No ongoing costs:** Local storage only, no backend infrastructure
- **Pay-per-use:** AI API costs only when generating coaching
- **Android-only:** No iOS support in MVP
- **Single time signature:** 4/4 only for MVP
- **Fixed duration:** 60-second sessions with 4-beat count-in

## Native Audio Implementation (Current Branch)

**Why Native AudioRecord?**
- flutter_sound doesn't expose Android's audio source options
- Android's AGC (Automatic Gain Control) was causing false positives
- Silence was being amplified to maximum (clipping at 1.0)
- Need direct control over audio input settings

**Implementation Details:**
- **Audio Source**: `MediaRecorder.AudioSource.VOICE_RECOGNITION`
  - Minimal AGC designed for speech recognition
  - Best balance between sensitivity and noise rejection
  - Alternative: `UNPROCESSED` (API 29+, may not be supported on all devices)
- **Sample Rate**: 44100 Hz (standard for music applications)
- **Format**: PCM 16-bit, Mono
- **Buffer**: 4x minimum buffer size for stability
- **Threading**: Background thread for I/O operations

**Platform Channel:**
- Channel name: `com.rhythmcoach.ai_rhythm_coach/native_audio`
- Methods: `initialize`, `startRecording`, `stopRecording`, `release`
- Bidirectional communication between Dart and Kotlin

**Files:**
- Native: `android/app/src/main/kotlin/.../NativeAudioRecorder.kt`
- Platform channel: `MainActivity.kt`
- Flutter wrapper: `lib/services/native_audio_recorder.dart`
- Integration: `lib/services/audio_service.dart` (uses NativeAudioRecorder)

**Testing:**
Use Python diagnostic tools in `quick_start_experiment/`:
```bash
cd quick_start_experiment
source venv/Scripts/activate
python analyze_new_recordings.py  # Compare silence vs drumming
```

**Expected Results:**
- Silence: RMS < 0.05, max < 0.9 (no clipping)
- Drumming: Clear amplitude spikes for hits
- No false positives from background noise

See `CLAUDE_SESSION_LOG.md` for complete implementation history and troubleshooting guide.

## Common Pitfalls to Avoid

- **Audio permissions:** Must request microphone permission on Android (handle in AudioService.initialize())
- **Emulator limitations:** Always test audio features on physical device
- **Native audio:** Only works on Android - native implementation uses Android AudioRecord API
- **Audio source support:** `UNPROCESSED` requires API 29+, may not work on all devices
- **FFT window size:** 2048 samples balances time/frequency resolution for rhythm detection
- **Onset threshold tuning:** Will require experimentation with real recordings
- **AGC behavior:** Different devices have different AGC implementations
- **API key security:** Never commit config.dart with real API keys
- **File cleanup:** Ensure old audio files deleted when sessions removed
- **State synchronization:** Always call notifyListeners() after state changes in controllers
- **Platform channels:** Ensure MainActivity is properly configured for method channel communication

## Git and CI/CD Best Practices

**Documentation-Only Commits:**
- **DO NOT trigger builds** for commits that only update documentation files
- Documentation files include: `*.md` files (README.md, CLAUDE.md, test plans, etc.)
- Use commit message prefix `[docs]` or `[skip ci]` for documentation-only changes
- Example: `git commit -m "[docs] Update testing documentation"`
- This saves CI/CD resources and build time
- Only trigger builds when actual code changes (`.dart`, `.yaml`, Android/iOS config files)

**When to Skip CI:**
- Documentation updates (`.md` files)
- Comment-only changes in code
- README or guide updates
- Test plan documentation
- Architecture diagrams or design docs

**When CI Must Run:**
- Any `.dart` file changes
- `pubspec.yaml` dependency changes
- Android manifest or iOS config changes
- Asset file additions/modifications
- Test file changes
- Build script modifications

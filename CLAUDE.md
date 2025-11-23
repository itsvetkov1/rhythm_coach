# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI Rhythm Coach is an Android mobile app that helps drummers and musicians improve rhythm accuracy through AI-powered coaching feedback. Users practice against a metronome, and the app analyzes their performance using onset detection algorithms and provides personalized coaching via Claude or GPT APIs.

**Current Status:** Planning phase - no code implementation yet. Complete technical specification exists.

**Platform:** Android (Flutter framework)
**MVP Scope:** 4/4 time signature, 40-200 BPM, 60-second practice sessions, local storage only

## Technology Stack

- **Framework:** Flutter/Dart
- **Audio:** flutter_sound (recording, playback, metronome)
- **DSP:** fftea (FFT for onset detection)
- **State Management:** Provider pattern
- **Persistence:** SharedPreferences (session metadata) + file system (audio files)
- **AI APIs:** Anthropic Claude or OpenAI GPT (configurable)
- **Key Dependencies:**
  - `provider: ^6.0.5` - State management
  - `flutter_sound: ^9.2.13` - Audio recording/playback
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
  - Records 60-second user audio to AAC format
  - Plays metronome clicks (high/low for downbeat emphasis)
  - Plays 4-beat count-in before recording
  - Manages flutter_sound recorder/player instances

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
│   ├── audio_service.dart      # Audio recording/playback
│   ├── rhythm_analyzer.dart    # FFT onset detection
│   └── ai_coaching_service.dart # AI API integration
├── screens/
│   ├── practice_screen.dart    # Main practice interface
│   └── results_screen.dart     # Session results display
└── widgets/                     # Reusable UI components

assets/
└── audio/
    ├── click_high.wav          # 800 Hz, 50ms (downbeat)
    └── click_low.wav           # 400 Hz, 50ms (other beats)

test/
├── models/                      # Model serialization tests
├── controllers/                 # Controller state tests
└── services/                    # Service unit tests (use mockito)
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
Raw Audio (AAC) → PCM Samples → FFT Windows → Spectral Flux
→ Onset Detection → Beat Matching → TapEvents with Errors
```

**Storage Strategy:**
- **Session Metadata:** SharedPreferences (JSON array, max 10 sessions)
- **Audio Files:** App documents directory (AAC format)
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

## Common Pitfalls to Avoid

- **Audio permissions:** Must request microphone permission on Android (handle in AudioService.initialize())
- **Emulator limitations:** Always test audio features on physical device
- **FFT window size:** 2048 samples balances time/frequency resolution for rhythm detection
- **Onset threshold tuning:** Will require experimentation with real recordings
- **API key security:** Never commit config.dart with real API keys
- **File cleanup:** Ensure old audio files deleted when sessions removed
- **State synchronization:** Always call notifyListeners() after state changes in controllers

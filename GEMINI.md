# GEMINI.md

This file provides essential context for the Gemini CLI agent when working with the `rhythm_coach` project. It summarizes the project's purpose, technical stack, architecture, and development guidelines.

## Project Overview

The AI Rhythm Coach is an Android mobile application developed with Flutter. Its primary goal is to help drummers and musicians improve their rhythm accuracy. The app achieves this by analyzing user performance against a metronome using AI-powered coaching feedback, which is generated via either the Anthropic Claude or OpenAI GPT APIs.

**Current Status:** The project is in the planning phase, with a complete technical specification but no code implementation yet.

**Platform:** Android (Flutter framework)
**MVP Scope:**
*   Supports 4/4 time signature.
*   BPM range: 40-200.
*   Practice session duration: 60 seconds.
*   Data storage: Local only.

## Technology Stack

*   **Framework:** Flutter/Dart
*   **Audio:** `flutter_sound` (recording, playback, metronome)
*   **DSP:** `fftea` (FFT for onset detection)
*   **State Management:** Provider pattern
*   **Persistence:** `shared_preferences` (session metadata) + file system (audio files)
*   **AI APIs:** Anthropic Claude or OpenAI GPT (configurable)

**Key Dependencies:**
*   `provider`
*   `flutter_sound`
*   `fftea`
*   `http`
*   `shared_preferences`
*   `path_provider`
*   `uuid`

## Architecture

The application follows a layered architecture:
1.  **Presentation Layer:** UI (screens and widgets).
2.  **State Management Layer:** Controllers utilizing the Provider pattern.
3.  **Service Layer:** `AudioService`, `RhythmAnalyzer`, `AICoachingService`.
4.  **Persistence Layer:** `SessionManager` (handles `SharedPreferences` and file system).

**Core Components:**
*   **`PracticeController` (`lib/controllers/practice_controller.dart`):** Orchestrates the practice session lifecycle (idle → countIn → recording → processing → completed/error).
*   **`SessionManager` (`lib/services/session_manager.dart`):** Manages persistence of session history (max 10 recent sessions), including metadata and audio files, with auto-deletion of oldest sessions.
*   **`AudioService` (`lib/services/audio_service.dart`):** Handles audio recording (AAC format), metronome playback (high/low clicks), and count-in.
*   **`RhythmAnalyzer` (`lib/services/rhythm_analyzer.dart`):** Performs FFT-based onset detection, matches onsets to expected beat times (±300ms tolerance), and calculates timing errors.
*   **`AICoachingService` (`lib/services/ai_coaching_service.dart`):** Formats session data into AI prompts, calls configured AI API, and returns coaching feedback.

## Data Models

*   **`Session` (`lib/models/session.dart`):** Stores session details (id, timestamp, bpm, duration, audio path, tap events, errors, coaching text). Supports JSON serialization.
*   **`TapEvent` (`lib/models/tap_event.dart`):** Records actual time, expected time, and error for each tap.
*   **`PracticeState` (enum):** Defines the various states of a practice session.

## Project Structure (Key Directories)

*   `lib/`: Contains the main application logic, including `main.dart`, `config.dart`, `models/`, `controllers/`, `services/`, `screens/`, and `widgets/`.
*   `assets/audio/`: Stores metronome click sound files (`click_high.wav`, `click_low.wav`).
*   `test/`: Contains unit and integration tests for models, controllers, and services.

## Development Commands

*   **Install Dependencies:** `flutter pub get`
*   **Run App:** `flutter run` (or `flutter run -d <device_id>`)
*   **Build APK:** `flutter build apk` (or `--debug`)
*   **Run Tests:** `flutter test` (or `flutter test test/path/file_test.dart` for specific files)
*   **Code Analysis:** `flutter analyze`
*   **Code Formatting:** `flutter format lib/`

## Configuration

**AI API Setup:**
*   Create `lib/config.dart` (this file is `.gitignore`d).
*   Example content for `lib/config.dart`:
    ```dart
    enum AIProvider { anthropic, openai }

    class AIConfig {
      static const AIProvider provider = AIProvider.anthropic;
      static const String anthropicApiKey = 'YOUR_ANTHROPIC_KEY';
      static const String openaiApiKey = 'YOUR_OPENAI_KEY';
    }
    ```
*   **API Key Security:** Never commit `lib/config.dart` with real API keys. Use environment variables or secure storage for production.

## Key Implementation Details

*   **Practice Session Flow:** User sets BPM, count-in, simultaneous recording and metronome, audio saved, rhythm analysis, AI coaching, session saved, results displayed.
*   **Audio Processing Pipeline:** Raw Audio (AAC) → PCM Samples → FFT Windows → Spectral Flux → Onset Detection → Beat Matching → TapEvents with Errors.
*   **Storage Strategy:** Session metadata in `SharedPreferences`, audio files in app documents directory. Local-only, no cloud sync.
*   **State Management:** Provider pattern with `ChangeNotifier` for reactive UI updates.

## Testing Strategy

*   **Unit Tests:** Cover data models, controller state transitions, session manager CRUD, and rhythm analyzer accuracy.
*   **Integration Tests:** End-to-end testing of the complete practice session flow.
*   **Manual Testing:** Essential on physical Android devices (emulators have limited audio support) to verify metronome timing, various BPMs, and tap intensities.

## Important Constraints

*   **Solo Developer Project:** Prioritize simplicity and avoid over-engineering.
*   **Flutter Beginner:** Use straightforward patterns.
*   **Cost-Effective:** No ongoing backend costs, AI API is pay-per-use.
*   **Android-Only MVP:** No iOS support initially.
*   **Fixed Parameters:** 4/4 time signature and 60-second sessions for MVP.

## Common Pitfalls to Avoid

*   **Audio Permissions:** Ensure microphone permission is requested on Android.
*   **Emulator Limitations:** Always test audio features on a physical device.
*   **FFT Tuning:** Onset threshold values will require experimentation.
*   **API Key Security:** Prevent committing `lib/config.dart` with sensitive keys.
*   **File Cleanup:** Implement proper deletion of old audio files.
*   **State Synchronization:** Use `notifyListeners()` correctly after state changes.

## Git and CI/CD Best Practices

*   **Documentation-Only Commits:** Use `[docs]` or `[skip ci]` prefix in commit messages for changes to `.md` files or comments to prevent unnecessary CI/CD builds.
*   **CI Must Run:** For any changes to `.dart` files, `pubspec.yaml`, Android/iOS config, assets, or build scripts.

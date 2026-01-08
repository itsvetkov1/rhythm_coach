# GEMINI_README.md

## Project Overview
**AI Rhythm Coach** is an Android mobile app (Flutter) designed to help musicians improve their rhythm.
**Core Function**: Records the user playing against a metronome, detects beat onsets via FFT, calculates strict timing errors, and generates AI-based coaching feedback.
**Current Phase**: MVP / Alpha. Core structural code exists, but significant audio timing and architecture issues require immediate remediation.

## Technology Stack
- **Framework**: Flutter (Dart)
- **State Management**: Provider (`ChangeNotifier` pattern)
- **Audio Engine**: `flutter_sound` (for Recording/Playback)
- **Signal Processing**: `fftea` (FFT-based onset detection)
- **Backend/AI**: Direct HTTP calls to Anthropic/OpenAI APIs (No intermediate backend)
- **Persistence**: `shared_preferences` (Metadata) + Local File System (WAV/AAC Audio)

## Architecture Summary
The app follows a layered architecture:
1.  **Presentation (UI)**: Screens (`PracticeScreen`, `ResultsScreen`) observe Controllers.
2.  **Logic (Controllers)**: `PracticeController` manages the session state machine (`idle` → `countIn` → `recording` → `processing`).
3.  **Services**:
    - `AudioService`: Manages hardware resources (Mic/Speaker).
    - `RhythmAnalyzer`: Pure Dart logic for converting Audio -> `List<TapEvent>`.
    - `AICoachingService`: Generates prompt for LLM based on `TapEvent` stats.
4.  **Data**: `Session` model holds the Source of Truth for a completed practice.

## 🔴 Critical Active Issues (Must Fix First)
*Refer to `ISSUES_TO_BE_FIXED.md` for full details.*

| ID | Issue | Severity | Impact | Proposed Solution |
|----|-------|----------|--------|-------------------|
| **#6** | **System Latency Ignored** | Critical | Timing is systematically wrong (approx 50-200ms offset). | Implement a calibration screen; subtract measured latency from all onset times. |
| **#5** | **Async Start Mismatch** | High | Recording & Metronome start sequentially, destroying alignment. | Use `Future.wait` for parallel start, or align via timestamps. |
| **#4** | **Metronome Drift** | High | `Timer.periodic` is not sample-accurate. | Use native audio scheduling or pre-rendered click tracks. |
| **#8** | **UI Thread Blocking** | Med | FFT analysis freezes the app for 3-4s. | Offload `RhythmAnalyzer.analyzeAudio` to a separate `Isolate`. |
| **#2** | **Format Mismatch** | Med | Code uses WAV, Docs say AAC. | Standardize on WAV for analysis accuracy; update docs. |

## Development Workflows
- **Run App**: `flutter run` (Use physical device for audio testing; emulators are unreliable for timing).
- **Run Tests**: `flutter test`
- **Dependencies**: `flutter pub get`
- **Documentation**: Keep `CLAUDE.md` and `technical_specification.md` in sync with code changes.

## Important Constraints
- **Offline First**: All audio stays local.
- **Precision**: Timing is everything. Code must prioritize sample-level accuracy over convenience.
- **Budget**: No recurring backend costs; direct API usage only.

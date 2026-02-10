# AI Rhythm Coach

## What This Is

An Android app built with Flutter that helps drummers and musicians improve their rhythm accuracy. Users practice playing along with a metronome, and the app analyzes their timing using FFT-based onset detection to show how accurately they're hitting beats. The app is partially built — metronome playback works, but audio recording and rhythm analysis are broken.

## Core Value

The practice loop must work reliably: user taps Start, hears a metronome, plays along, and sees accurate timing results showing how early/late each beat was.

## Requirements

### Validated

- ✓ Metronome playback at configurable BPM (40-200) with count-in — existing
- ✓ BPM control UI with +/- adjustment — existing
- ✓ High/low click differentiation (downbeat emphasis) — existing

### Active

- [ ] Audio recording captures user's playing via microphone during practice session
- [ ] Recorded audio is saved as a valid, non-corrupt file
- [ ] FFT-based onset detection correctly identifies beat hits from recorded audio
- [ ] Detected onsets are matched to expected beat times with timing error calculation
- [ ] Timing results are displayed to user showing per-beat accuracy (early/late/on-time)
- [ ] Complete practice session flow works end-to-end without crashes
- [ ] Latency calibration compensates for device audio latency

### Out of Scope

- AI coaching feedback (Claude/GPT integration) — deferring until audio pipeline is solid
- Session history and persistence — not needed until core loop works
- iOS support — Android only for MVP
- Multiple time signatures — 4/4 only
- Variable session duration — fixed 60-second sessions
- Play Store publishing — stabilize first

## Context

- Flutter/Dart project using flutter_sound for audio, fftea for FFT analysis
- Existing codebase has partial implementation across all layers (services, controllers, models, UI)
- Recording issues: mic capture fails or produces empty/corrupt audio files
- Analysis issues: onset detection returns incorrect timing results
- Tested on both physical Android device and emulator
- Emulator has known audio limitations — physical device testing essential for audio features
- Audio pipeline: Raw Audio (AAC) → PCM Samples → FFT Windows → Spectral Flux → Onset Detection → Beat Matching
- Calibration service exists for latency offset compensation

## Constraints

- **Platform**: Android only — no iOS consideration needed
- **Framework**: Flutter/Dart — existing codebase, don't rewrite
- **Audio library**: flutter_sound — already integrated
- **FFT library**: fftea — already integrated
- **Solo developer**: Keep solutions simple, avoid over-engineering
- **No backend**: All processing and storage is local

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Fix audio pipeline before AI integration | Can't coach on bad data — garbage in, garbage out | — Pending |
| Keep flutter_sound and fftea | Already integrated, switching libraries adds risk | — Pending |
| 4/4 time only for MVP | Reduces complexity of beat matching and analysis | — Pending |
| AAC recording format | flutter_sound default, good compression | — Pending |

---
*Last updated: 2026-02-10 after initialization*

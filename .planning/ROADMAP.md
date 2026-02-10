# Roadmap: AI Rhythm Coach

## Overview

This roadmap delivers the core practice loop: a user taps Start, hears a metronome, plays along, and sees accurate timing results. The existing codebase has working metronome playback but broken audio recording and rhythm analysis. We fix the audio pipeline first (recording, session config, file validation), then build accurate onset detection, add latency calibration for fair feedback, and finally wire up the results display to complete the end-to-end flow. Each phase builds on the previous -- nothing downstream works if recording is broken.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Audio Recording** - Fix broken audio capture so microphone recording produces valid WAV files
- [ ] **Phase 2: Onset Detection** - Accurately identify beat hits from recorded audio using FFT analysis
- [ ] **Phase 3: Latency Calibration** - Compensate for device-specific audio latency so timing results are fair
- [ ] **Phase 4: Results Display** - Show per-beat timing accuracy and complete the end-to-end practice loop

## Phase Details

### Phase 1: Audio Recording
**Goal**: User's playing is reliably captured to valid WAV files while metronome plays simultaneously
**Depends on**: Nothing (first phase)
**Requirements**: AUD-01, AUD-02, AUD-03, AUD-04
**Success Criteria** (what must be TRUE):
  1. User taps Start, plays along with metronome, and a WAV file is saved containing their audio
  2. Metronome clicks are audible during recording and do not bleed into the recorded audio file
  3. Audio session routing is configured so playback and recording happen simultaneously without conflict
  4. After recording completes, the saved file is non-empty, has correct WAV headers, and contains audible PCM16 audio data
**Plans**: TBD

Plans:
- [ ] 01-01: TBD
- [ ] 01-02: TBD

### Phase 2: Onset Detection
**Goal**: Beat hits in recorded audio are accurately identified and matched to expected beat times
**Depends on**: Phase 1 (requires valid WAV recordings to analyze)
**Requirements**: RHY-01, RHY-02
**Success Criteria** (what must be TRUE):
  1. FFT-based spectral flux analysis detects onset times that correspond to actual drum hits in a recording
  2. Each detected onset is matched to the nearest expected beat time and the timing error (early/late in milliseconds) is calculated
  3. Detection works across a range of tap volumes (soft to loud) and BPM settings (40-200)
**Plans**: TBD

Plans:
- [ ] 02-01: TBD

### Phase 3: Latency Calibration
**Goal**: Device-specific audio latency is measured and compensated so users are not blamed for hardware delays
**Depends on**: Phase 2 (requires working onset detection to validate calibration)
**Requirements**: RHY-03
**Success Criteria** (what must be TRUE):
  1. User can run a calibration routine that measures their device's audio latency offset
  2. The measured latency offset is stored and automatically applied to timing calculations in all future sessions
  3. After calibration, a user playing perfectly in time shows near-zero timing errors (not systematically early or late)
**Plans**: TBD

Plans:
- [ ] 03-01: TBD

### Phase 4: Results Display
**Goal**: Users see clear, actionable timing results after each practice session
**Depends on**: Phase 3 (requires calibrated timing data for accurate results)
**Requirements**: RES-01, RES-02, RES-03
**Success Criteria** (what must be TRUE):
  1. After a practice session completes, the user is taken to a results screen showing per-beat accuracy (early/late/on-time for each beat)
  2. Average timing error and consistency score are calculated and displayed as summary metrics
  3. The complete practice flow works end-to-end without crashes: Start -> count-in -> metronome + recording -> analysis -> results screen
**Plans**: TBD

Plans:
- [ ] 04-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Audio Recording | 0/TBD | Not started | - |
| 2. Onset Detection | 0/TBD | Not started | - |
| 3. Latency Calibration | 0/TBD | Not started | - |
| 4. Results Display | 0/TBD | Not started | - |

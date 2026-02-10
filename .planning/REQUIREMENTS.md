# Requirements: AI Rhythm Coach

**Defined:** 2026-02-10
**Core Value:** The practice loop must work reliably: user taps Start, hears a metronome, plays along, and sees accurate timing results showing how early/late each beat was.

## v1 Requirements

Requirements for getting the core practice loop working end-to-end.

### Audio Infrastructure

- [ ] **AUD-01**: User's playing is captured via microphone and saved as valid WAV/PCM16 file
- [ ] **AUD-02**: Metronome plays simultaneously during recording without corrupting audio capture
- [ ] **AUD-03**: Audio session is configured for proper input/output routing (playAndRecord mode)
- [ ] **AUD-04**: Recording file is validated for integrity (non-empty, correct format) after capture

### Rhythm Analysis

- [ ] **RHY-01**: FFT-based onset detection correctly identifies beat hits from recorded audio
- [ ] **RHY-02**: Detected onsets are matched to expected beat times with timing error in milliseconds
- [ ] **RHY-03**: Device audio latency is calibrated and compensated for in timing calculations

### Results Display

- [ ] **RES-01**: Per-beat timing accuracy is displayed showing early/late/on-time for each beat
- [ ] **RES-02**: Average error and consistency metrics are calculated and displayed
- [ ] **RES-03**: Session results are shown on a dedicated results screen after practice

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### AI Coaching

- **COACH-01**: AI generates 2-3 sentence coaching feedback from session timing data
- **COACH-02**: Coaching feedback identifies strengths and specific improvement areas
- **COACH-03**: AI provider is configurable (Claude or GPT)

### Session History

- **HIST-01**: Last 10 sessions are persisted with metadata (BPM, timestamp, metrics)
- **HIST-02**: Oldest sessions auto-deleted when limit exceeded
- **HIST-03**: Session history is viewable in a list

### Progress Tracking

- **PROG-01**: User can see improvement trends across sessions
- **PROG-02**: Session audio is available for playback review

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| AI coaching feedback | Deferring until audio pipeline is solid -- can't coach on bad data |
| Session persistence | Not needed until core loop works |
| iOS support | Android only for MVP |
| Multiple time signatures | 4/4 only -- reduces analysis complexity |
| Variable session duration | Fixed 60-second sessions |
| Play Store publishing | Stabilize first |
| Real-time visual feedback | Technically complex, post-practice analysis sufficient |
| Social features | Solo practice app, no backend needed |
| Subscription model | Pay-per-use AI coaching later, basic features free |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUD-01 | Phase 1: Audio Recording | Pending |
| AUD-02 | Phase 1: Audio Recording | Pending |
| AUD-03 | Phase 1: Audio Recording | Pending |
| AUD-04 | Phase 1: Audio Recording | Pending |
| RHY-01 | Phase 2: Onset Detection | Pending |
| RHY-02 | Phase 2: Onset Detection | Pending |
| RHY-03 | Phase 3: Latency Calibration | Pending |
| RES-01 | Phase 4: Results Display | Pending |
| RES-02 | Phase 4: Results Display | Pending |
| RES-03 | Phase 4: Results Display | Pending |

**Coverage:**
- v1 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0

---
*Requirements defined: 2026-02-10*
*Last updated: 2026-02-10 after roadmap creation*

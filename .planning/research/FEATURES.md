# Feature Landscape

**Domain:** Rhythm/Music Practice Apps (Drummer Focus)
**Researched:** 2026-02-10
**Confidence:** MEDIUM

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Accurate metronome with audible click | All rhythm apps have this - it's the foundation | Low | Must be accurate (±20μs ideal). Users will compare against other metronome apps and notice if it drifts |
| Visual beat indicator | Users expect to see where they are in the measure | Low | Flashing indicator, circular/linear display, or animated pendulum. Essential for noisy environments |
| BPM adjustment (wide range) | Users practice at different tempos based on skill level | Low | 40-200 BPM minimum. Tap tempo is expected. Fine control (1 BPM increments) required |
| Time signature support (4/4 minimum) | 4/4 is universal - users expect it | Low | MVP can start with 4/4 only. Other signatures (3/4, 6/8, etc.) are differentiators |
| Downbeat emphasis | Users need to hear where measure starts | Low | Higher pitch or louder click on beat 1. Prevents getting lost during practice |
| Start/stop controls | Basic session control | Low | Clear, accessible controls. Optional: count-in before start (3-4 beats) |
| Session timing display | Users want to know how long they've practiced | Low | Real-time timer showing elapsed time during practice |

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Timing accuracy analysis (early/late detection) | Shows WHAT went wrong, not just that something was wrong | High | Requires audio recording + onset detection. Display per-beat errors in milliseconds. Apps like Rhythm Trainer by Rhythmicity do this |
| Real-time visual feedback during recording | Immediate correction vs post-practice review | High | Technically challenging (latency issues). May require wired headphones for zero latency |
| AI-powered coaching feedback | Personalized, contextual improvement suggestions vs generic tips | Medium | Main differentiator for AI Rhythm Coach. Must focus on strengths + specific improvement areas (not generic) |
| Progress tracking across sessions | Helps users see improvement over time | Medium | Track metrics like average error, consistency, streak days. Apps like Drummer ITP and Drumbitious have this |
| Automatic tempo progression | Gradually increases tempo as user improves | Medium | "Speed Upper" feature - set start/end tempo with gradual increases. Soundbrenner has this |
| Muted beat trainer | Tests internal timing by randomly muting metronome | Medium | Forces user to maintain tempo internally. Soundbrenner offers this |
| Session history with playback | Review past performances to identify patterns | Medium | Store audio files + analysis results. Limit storage (10 sessions typical) |
| Per-beat accuracy visualization | Graphical display of timing errors across the session | Medium | Chart showing early/late for each beat. Makes patterns visible at a glance |
| Subdivision support | Practice against eighth notes, triplets, sixteenths | Low-Medium | Differentiator for intermediate/advanced users. MVP can defer this |
| Custom click sounds | Personalization of metronome tone | Low | Some users prefer different sounds. Not critical but valued |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Built-in tuner | Unnecessary bloat - users have dedicated tuner apps and mixing tools reduces app quality | Keep focused on rhythm training only. Users prefer specialized tools |
| Social features (sharing, leaderboards) | Adds complexity, ongoing moderation costs, privacy concerns for solo practice app | Focus on individual improvement. Personal progress is motivating enough |
| Real-time collaborative practice | Requires backend infrastructure, networking code, synchronization complexity | Local-only practice. Cloud sync is acceptable for backups but not real-time |
| Subscription model for basic features | Users resist paying monthly for practice tools they use sporadically | One-time purchase or pay-per-use (like AI coaching). Keep metronome/basic features free |
| Auto-start timers | Users find it frustrating when sessions start without explicit confirmation | Always require explicit start action. Optional: prompt for confirmation |
| Intrusive rating prompts | Breaks practice flow, annoys users | Single prompt after 5+ successful sessions, with permanent dismiss option |
| Game-ification with points/badges | Creates extrinsic motivation that can backfire. Practice is serious | Focus on actual skill metrics (accuracy, consistency) vs arbitrary points |
| Video recording | Massive storage requirements, not needed for rhythm analysis | Audio-only is sufficient for onset detection |
| Multiple instruments in single session | Complicates UI and analysis. Users practice one instrument at a time | Single instrument focus. Track instrument separately if needed |
| Complex pattern/rhythm library | Overwhelming for beginners, maintenance burden | Focus on free-form practice against metronome. Users create their own patterns |

## Feature Dependencies

```
Metronome (audible + visual)
    └──requires──> BPM controls
    └──requires──> Time signature
    └──requires──> Downbeat emphasis

Audio recording
    └──requires──> Metronome (to play during recording)
    └──enables──> Timing analysis
    └──enables──> Session playback

Timing analysis (onset detection)
    └──requires──> Audio recording
    └──enables──> Per-beat accuracy display
    └──enables──> Average error calculation
    └──enables──> AI coaching (context for prompts)

AI coaching
    └──requires──> Timing analysis results
    └──enhances──> Progress tracking (qualitative insights)

Session history
    └──requires──> Data persistence (metadata + audio files)
    └──enables──> Progress tracking
    └──enables──> Session playback

Progress tracking
    └──requires──> Session history
    └──enhances with──> Timing analysis metrics

Muted beat trainer
    ──conflicts with──> Visual real-time feedback (defeats purpose)
```

### Dependency Notes

- **Timing analysis requires audio recording:** You can't analyze what you don't record. This is the critical path.
- **AI coaching requires timing analysis:** Generic coaching is worthless. Need actual performance data.
- **Session history enables progress tracking:** Can't track progress without storing results.
- **Muted beat trainer conflicts with visual feedback:** The point is to internalize timing without cues, so visual feedback undermines the training goal.

## MVP Definition

### Launch With (v1)

Minimum viable product to validate core value proposition.

- [ ] Accurate metronome (audible click + visual beat indicator) — Foundation for all practice
- [ ] BPM adjustment (40-200, tap tempo, 1 BPM increments) — Essential for usability across skill levels
- [ ] 4/4 time signature with downbeat emphasis — Table stakes, universally needed
- [ ] 4-beat count-in before recording — Prevents jarring transitions, gives user time to prepare
- [ ] Audio recording (60 seconds) during metronome playback — Required for timing analysis
- [ ] FFT-based onset detection + timing analysis — Core differentiator, validates concept
- [ ] Per-beat accuracy display (early/late, milliseconds) — Shows value of timing analysis
- [ ] Average error + consistency metrics — Summary statistics for quick assessment
- [ ] Session results screen with metrics — Must show analysis results clearly
- [ ] Session history (last 10 sessions, metadata only) — Enables basic progress tracking without excessive storage

**Defer to post-MVP:**
- AI coaching (can validate timing analysis first, add AI later)
- Session audio playback (metadata/metrics are sufficient initially)
- Progress tracking graphs (history list is enough for MVP)

### Add After Validation (v1.x)

Features to add once core practice loop is proven.

- [ ] AI coaching feedback (2-3 sentences) — Add once timing analysis is working well. Trigger: Users request interpretation help
- [ ] Session audio playback — Enable review of actual performance. Trigger: Users want to hear what happened
- [ ] Progress tracking across sessions — Visualize improvement over time. Trigger: Users practice 5+ sessions
- [ ] Export session data (CSV/JSON) — For external analysis. Trigger: Power users request it
- [ ] Custom click sounds — Personalization. Trigger: Complaints about default sound
- [ ] Subdivision support (eighth notes, triplets) — For intermediate users. Trigger: Users consistently score >90% accuracy

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Muted beat trainer — Advanced feature for experienced drummers. Defer: Requires strong internal timing already
- [ ] Automatic tempo progression — Nice automation. Defer: Users can manually adjust BPM
- [ ] Real-time visual feedback during practice — Technically complex (latency). Defer: Post-practice analysis works fine
- [ ] Multiple time signatures (3/4, 6/8, 5/4, etc.) — Broader appeal. Defer: 4/4 covers 90% of use cases
- [ ] Polyrhythm support — Advanced feature. Defer: Small user segment
- [ ] Practice reminders/scheduling — Nice-to-have. Defer: Not core to practice quality

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Metronome (audible + visual) | HIGH | LOW | P1 |
| BPM controls (40-200, tap tempo) | HIGH | LOW | P1 |
| 4-beat count-in | HIGH | LOW | P1 |
| Audio recording | HIGH | MEDIUM | P1 |
| Onset detection + timing analysis | HIGH | HIGH | P1 |
| Per-beat accuracy display | HIGH | MEDIUM | P1 |
| Average error + consistency | HIGH | LOW | P1 |
| Session results screen | HIGH | LOW | P1 |
| Session history (metadata) | MEDIUM | LOW | P1 |
| AI coaching feedback | HIGH | MEDIUM | P2 |
| Session audio playback | MEDIUM | LOW | P2 |
| Progress tracking visualization | MEDIUM | MEDIUM | P2 |
| Export session data | LOW | LOW | P2 |
| Custom click sounds | LOW | LOW | P3 |
| Subdivision support | MEDIUM | MEDIUM | P3 |
| Muted beat trainer | MEDIUM | MEDIUM | P3 |
| Automatic tempo progression | MEDIUM | MEDIUM | P3 |
| Real-time visual feedback | LOW | HIGH | P3 |
| Multiple time signatures | MEDIUM | MEDIUM | P3 |
| Polyrhythm support | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch (validates core value)
- P2: Should have, add when core works (enhances value)
- P3: Nice to have, future consideration (expands user base)

## Competitor Feature Analysis

| Feature | Soundbrenner (market leader) | Rhythm Trainer by Rhythmicity | Our Approach (AI Rhythm Coach) |
|---------|------------------------------|-------------------------------|--------------------------------|
| Metronome | Advanced (vibrating wearable integration, polyrhythms) | Basic audio metronome | Standard audio + visual (no hardware) |
| Timing analysis | Practice tracking (hours, streaks) | Shows early/late per beat with millisecond accuracy | FFT onset detection + millisecond-level per-beat errors |
| Feedback | Muted beat trainer, incremental tempo change | Graded exercises (beginner to advanced) | AI-powered personalized coaching (2-3 sentences) |
| Progress tracking | Detailed tracking, separate per instrument | Exercise progression tracking | Session history with accuracy trends |
| Practice sessions | Unlimited duration | Structured exercises with grading | Fixed 60-second sessions for consistency |
| Differentiation | Hardware integration (wearable metronome) | Structured curriculum approach | AI coaching based on actual performance data |

**Our competitive positioning:**
- **Simpler than Soundbrenner:** No hardware required, focused on software-only timing analysis
- **More personalized than Rhythm Trainer:** AI coaching vs generic exercise grading
- **Faster feedback loop:** 60-second sessions for quick iteration vs long practice sessions
- **Lower barrier:** Free metronome + onset detection, pay-per-use AI coaching vs subscription

## Sources

**Confidence level: MEDIUM** - Based on web search results from 2026, verified across multiple sources. No official API documentation reviewed (not applicable to feature research).

### Metronome Features
- [The Metronome by Soundbrenner](https://play.google.com/store/apps/details?id=com.soundbrenner.pulse&hl=en_US)
- [Best Metronome Apps for Drummers in 2026 | Melodics](https://melodics.com/blog/best-metronome-apps-for-drummers-2026)
- [8 Great Rhythm Training Apps and Websites (2026) - Musician Wave](https://www.musicianwave.com/rhythm-training-apps-websites/)

### Timing Analysis and Feedback
- [Rhythm Trainer by Rhythmicity App](https://apps.apple.com/us/app/rhythm-trainer-by-rhythmicity/id766756872)
- [Complete Rhythm Trainer - Apps on Google Play](https://play.google.com/store/apps/details?id=com.binaryguilt.completerhythmtrainer&hl=en_US)
- [Software to check the rhythm accuracy in real time - Gearspace](https://gearspace.com/board/so-many-guitars-so-little-time/883379-software-check-rhythm-accuracy-real-time.html)

### Progress Tracking
- [Drummer ITP - App Overview | Drum Tuner App](https://www.idrumtune.com/drummer-itp-app-overview-and-main-features/)
- [Drumr app](https://drumr.app/)
- [Drum Practice App: Drumbitious App](https://apps.apple.com/us/app/drum-practice-app-drumbitious/id1552236632)

### Audio Recording and Onset Detection
- [13 Best Drumming Apps That You'll Actually Use – Drum Spy](https://drumspy.com/gear-guides/drumming-apps/)
- [ADC 2024 - Onset Detection | Jordie Shier](https://jordieshier.com/adc2024/)

### Visual Feedback
- [Pro Metronome - Tempo & Tuner App](https://apps.apple.com/us/app/pro-metronome-tempo-tuner/id477960671)
- [The Most Accurate Metronome for iPhone](https://metronomeapp.com/)

### Anti-Features
- [Tonic Practice App: A good idea, but not yet there](https://www.violinist.com/discussion/thread.cfm?page=6757)
- [Andante Music Practice Journal](https://andante.app/)

### User Expectations
- [Music Rhythm Trainer App](https://apps.apple.com/us/app/music-rhythm-trainer/id1319997438)
- [11 Best Metronome Apps to Improve Your Rhythm & Timing - UMA Technology](https://umatechnology.org/11-best-metronome-apps-to-improve-your-rhythm-timing/)

---
*Feature research for: AI Rhythm Coach*
*Researched: 2026-02-10*

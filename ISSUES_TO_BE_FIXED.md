# Issues to be Fixed

This document tracks implementation issues that need to be resolved for the AI Rhythm Coach app.

For detailed analysis, see `IMPLEMENTATION_ISSUES.md`.

---

## 🔴 CRITICAL (Must Fix - App Won't Work Correctly)

### ✓ Issue #1: Metronome Clicks Recorded with User Performance
**Status**: Fixed (Workaround Implemented)
**Priority**: CRITICAL
**Impact**: Breaks rhythm detection - metronome clicks detected as user beats

**Location**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:53-55`

**Fix Implemented**:
- Added mandatory "Connect Headphones" warning dialog on startup
- Relies on Android OS automatic audio routing to separate output (headphones) from input (built-in mic)
- Added `MetronomeBleedException` in analyzer to detect if bleed still occurs (consistency < 3ms)

---

### ✓ Issue #3: Improper WAV File Parsing
**Status**: Fixed
**Priority**: CRITICAL
**Impact**: Skips 1024 bytes instead of 44-byte header, reads garbage data

**Location**: `ai_rhythm_coach/lib/services/rhythm_analyzer.dart:62`

**Fix Implemented**:
```dart
// Changed to:
final startIndex = min(44, bytes.length);
```

---

### ✗ Issue #6: System Audio Latency Not Accounted For
**Status**: Not Fixed
**Priority**: CRITICAL
**Impact**: All timing measurements systematically wrong by 50-200ms

**Location**: No latency compensation anywhere in codebase

**Fix Required**:
- Add latency calibration routine
- Measure device-specific input/output latency
- Subtract from timing calculations

---

## 🟡 HIGH (Should Fix Before MVP)

### ✗ Issue #2: Audio Format Mismatch (WAV vs AAC)
**Status**: Not Fixed
**Priority**: HIGH
**Impact**: Documentation says AAC, code uses WAV (10-20x larger files)

**Location**: `ai_rhythm_coach/lib/services/audio_service.dart:122`

**Fix Required**:
- Either change to `Codec.aacADTS` or update documentation
- Recommendation: Keep WAV (better for analysis), update docs

---

### ✗ Issue #4: Metronome Timing Drift
**Status**: Not Fixed
**Priority**: HIGH
**Impact**: Timer.periodic() causes drift, metronome becomes inaccurate

**Location**: `ai_rhythm_coach/lib/services/audio_service.dart:155`

**Fix Required**:
- Use sample-accurate timing instead of Timer.periodic()
- Pre-generate metronome track or use audio scheduling API

---

### ✗ Issue #5: Recording and Metronome Not Simultaneous
**Status**: Not Fixed
**Priority**: HIGH
**Impact**: 50-100ms misalignment between recording start and metronome

**Location**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:54-55`

**Fix Required**:
```dart
// Change from sequential:
await _audioService.startRecording();
await _audioService.startMetronome(_bpm);

// To parallel:
await Future.wait([
  _audioService.startRecording(),
  _audioService.startMetronome(_bpm),
]);
```

---

### ✗ Issue #7: Onset Detection Timing Error
**Status**: Not Fixed
**Priority**: HIGH
**Impact**: Up to 46ms random timing error per onset

**Location**: `ai_rhythm_coach/lib/services/rhythm_analyzer.dart:120`

**Fix Required**:
- Find peak within FFT window and interpolate
- Or use smaller hop size for better temporal accuracy

---

## 🟠 MEDIUM (Fix for Better UX)

### ✗ Issue #8: FFT Processing Blocks UI Thread
**Status**: Not Fixed
**Priority**: MEDIUM
**Impact**: App freezes for 2-4 seconds, poor UX

**Location**: `ai_rhythm_coach/lib/services/rhythm_analyzer.dart:79-132`

**Fix Required**:
- Run FFT analysis in separate isolate using `compute()`
- Add progress indication

---

### ✗ Issue #9: AI API Failure Discards Entire Session
**Status**: Not Fixed
**Priority**: MEDIUM
**Impact**: User loses practice data if network fails

**Location**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:77-126`

**Fix Required**:
- Save session even if AI call fails
- Use fallback coaching text: "Coaching unavailable (network error)"
- Allow retry later

---

### ✓ Issue #10: No Spectral Flux Normalization
**Status**: Fixed
**Priority**: MEDIUM
**Impact**: Fixed threshold fails for different recording volumes

**Location**: `ai_rhythm_coach/lib/services/rhythm_analyzer.dart:109-120`

**Fix Implemented**:
- Implemented normalized spectral flux (flux / previousEnergy)
- Updated thresholds: onsetThreshold = 0.15, minSignalEnergy = 0.0001

---

### ✗ Issue #11: Recording Duration Inaccuracy
**Status**: Not Fixed
**Priority**: MEDIUM
**Impact**: Recording is ~60.1-60.5s instead of exactly 60s

**Location**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:54-66`

**Fix Required**:
- Use precise timing: record start time, wait until exactly 60s elapsed
- Or adjust expected beats to match actual duration

---

### ✗ Issue #12: Count-In Timing Drift
**Status**: Not Fixed
**Priority**: MEDIUM
**Impact**: Count-in rhythm inconsistent, accumulates drift

**Location**: `ai_rhythm_coach/lib/services/audio_service.dart:94-106`

**Fix Required**:
- Schedule all 4 clicks based on wall clock, not sequential delays
- Use audio scheduling API if available

---

### ✗ Issue #13: No Memory Management for Large Audio Files
**Status**: Not Fixed
**Priority**: MEDIUM
**Impact**: ~21MB in memory, potential OOM on low-end devices

**Location**: `ai_rhythm_coach/lib/services/rhythm_analyzer.dart:45-76`

**Fix Required**:
- Stream file in chunks instead of loading entirely
- Process incrementally and release memory

---

## 🔵 LOW (Polish and Edge Cases)

### ✗ Issue #14: No Disk Space Check Before Recording
**Status**: Not Fixed
**Priority**: LOW
**Fix**: Check available space before starting, warn if < 50MB

### ✗ Issue #15: Mock API Response Not Visible to User
**Status**: Not Fixed
**Priority**: LOW
**Fix**: Show UI warning when using demo mode

### ✗ Issue #16: No Validation Check Before Starting Session
**Status**: Not Fixed
**Priority**: LOW
**Fix**: Validate BPM in range [40, 200] before starting

### ✗ Issue #17: Session Cleanup Only on Save
**Status**: Not Fixed
**Priority**: LOW
**Fix**: Clean up orphaned audio files on app startup

### ✗ Issue #18: Race Condition in Metronome Stop
**Status**: Not Fixed
**Priority**: LOW
**Fix**: Stop player explicitly before cancelling timer

### ✓ Issue #19: No Recovery from Partial Recording
**Status**: Fixed
**Priority**: LOW
**Fix**: Implemented "Stop & Analyze" feature allowing users to end session early and still get results.

### ✗ Issue #20: Shared Player Instance Issues
**Status**: Not Fixed
**Priority**: LOW
**Fix**: Use separate player instances or wait for completion

### ✗ Issue #21: No Progress Indication During Processing
**Status**: Not Fixed
**Priority**: LOW
**Fix**: Show detailed progress: "Analyzing audio...", "Generating coaching..."

### ✗ Issue #22: No Audio Monitoring During Recording
**Status**: Not Fixed
**Priority**: LOW (Feature Request)
**Fix**: Add audio passthrough/monitoring option

### ✗ Issue #23: Timezone Handling in Session Timestamps
**Status**: Not Fixed
**Priority**: LOW
**Fix**: Always use UTC for storage, convert to local for display

### ✗ Issue #24: No Calibration for Device-Specific Audio Latency
**Status**: Not Fixed
**Priority**: MEDIUM (Related to Issue #6)
**Fix**: Add calibration screen to measure device latency

---

## Fix Priority Order

1. **#1** - Metronome in recording (breaks core functionality)
2. **#3** - WAV parsing (reading wrong data)
3. **#6** - Audio latency (measurements systematically wrong)
4. **#4** - Metronome drift (poor metronome accuracy)
5. **#9** - API failure handling (don't lose user data)
6. **#5** - Simultaneous start (timing alignment)
7. **#8** - UI blocking (user experience)
8. **#10** - Onset threshold (detection accuracy)
9. **#2** - Format documentation (consistency)
10. **Others** - Based on user feedback and testing

---

## Testing After Fixes

- [ ] Test with different recording volumes (loud, quiet, very quiet)
- [ ] Test at different BPMs (40, 120, 200)
- [ ] Test on multiple Android devices (different latencies)
- [ ] Test with headphones vs speakers
- [ ] Test network failure scenarios
- [ ] Test with nearly-full storage
- [ ] Test rapid start/stop/restart
- [ ] Verify metronome timing accuracy with external reference
- [ ] Verify onset detection with known test audio files
- [ ] Compare timing measurements with ground truth

---

**Last Updated**: 2025-12-04
**Total Issues**: 24
**Fixed**: 4
**Critical**: 1 (Remaining)
**High**: 4
**Medium**: 4
**Low**: 10

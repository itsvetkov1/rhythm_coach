# PRD: Complete Onset Detection Rework - Eliminate False Positives

## Introduction

The current onset detection system produces false positives, detecting "beats" during complete silence and from background noise (AC, breathing, room ambience). This breaks the core functionality of the app, as users cannot get accurate rhythm coaching if phantom beats are being counted.

This PRD outlines a complete rework of the onset detection algorithm to achieve zero false positives while maintaining accurate detection of actual drum hits. The solution will include diagnostic instrumentation, noise floor measurement, adaptive thresholding, improved spectral analysis, and comprehensive automated testing.

## Goals

- **Zero false positives**: No beats detected during silence or background noise
- **Maintain drum hit accuracy**: Real drum hits still detected with ≥95% accuracy
- **Diagnostic visibility**: Comprehensive logging to understand detection behavior
- **Automated validation**: Test suite that catches regressions
- **Tunable parameters**: Easy adjustment of sensitivity without code changes
- **Scientific validation**: Python tools to analyze algorithm performance

## User Stories

### US-001: Add diagnostic instrumentation to RhythmAnalyzer
**Description:** As a developer, I need detailed logging of the onset detection pipeline so I can understand why false positives occur.

**Acceptance Criteria:**
- [x] Add optional `debugMode` parameter to `analyzeRecording()` method
- [x] Log raw spectral flux values for each frame
- [x] Log threshold values being used for onset detection
- [x] Log all detected onset times with confidence scores
- [x] Log noise floor measurement if calculated
- [x] Save debug output to file in app documents directory when enabled
- [x] Typecheck passes

### US-002: Create synthetic test audio files
**Description:** As a developer, I need synthetic audio samples (silence, noise, drum hits) so I can write automated tests.

**Acceptance Criteria:**
- [x] Generate `test_silence.wav`: 5 seconds of digital silence (all zeros)
- [x] Generate `test_white_noise.wav`: 5 seconds of low-level white noise (RMS ~0.05)
- [x] Generate `test_drum_hits.wav`: 8 clean impulse sounds at 120 BPM
- [x] All files are 44.1kHz, mono, PCM 16-bit WAV format
- [x] Save files to `test/fixtures/audio/` directory
- [x] Add helper function `loadTestAudioFixture(filename)` in test utils
- [x] Typecheck passes

### US-003: Add automated tests for false positive prevention
**Description:** As a developer, I want automated tests that fail when false positives occur so I catch regressions.

**Acceptance Criteria:**
- [x] Test: `test_silence.wav` produces zero detected onsets
- [x] Test: `test_white_noise.wav` produces zero detected onsets
- [x] Test: `test_drum_hits.wav` detects exactly 8 onsets (±1 acceptable)
- [x] Tests currently FAIL with existing algorithm (expected)
- [x] Add test file: `test/services/rhythm_analyzer_false_positive_test.dart`
- [x] Typecheck passes

### US-004: Implement noise floor measurement
**Description:** As a system, I need to measure the ambient noise level before onset detection so I can set adaptive thresholds.

**Acceptance Criteria:**
- [x] Add `_measureNoiseFloor(List<double> samples)` method to RhythmAnalyzer
- [x] Use first 1 second of audio (44100 samples) for noise measurement
- [x] Calculate RMS (root mean square) energy of noise sample
- [x] Return noise floor value (0.0 to 1.0 scale)
- [x] Add unit test for noise floor calculation with known test signals
- [x] Typecheck passes

### US-005: Implement high-pass filter preprocessing
**Description:** As a system, I need to filter out low-frequency rumble and DC offset so they don't trigger false onsets.

**Acceptance Criteria:**
- [x] Add `_applyHighPassFilter(List<double> samples, double cutoffHz)` method
- [x] Implement simple first-order high-pass filter (cutoff at 60 Hz)
- [x] Apply filter to entire audio buffer before FFT analysis
- [x] Filter removes DC offset and rumble below 60 Hz
- [x] Add unit test verifying DC offset removal
- [x] Typecheck passes

### US-006: Implement improved spectral flux calculation
**Description:** As a system, I need better spectral flux calculation that focuses on drum hit frequencies and ignores noise.

**Acceptance Criteria:**
- [x] Refactor `_calculateSpectralFlux()` to use frequency-weighted approach
- [x] Focus on 200Hz-4000Hz range (primary drum hit energy)
- [x] Ignore bins below 200Hz (rumble, handling noise)
- [x] Ignore bins above 8000Hz (electronic noise, aliasing)
- [x] Use Half-Wave Rectification (only count increases in energy)
- [x] Add unit test with synthetic frequency sweep
- [x] Typecheck passes

### US-007: Implement adaptive threshold calculation
**Description:** As a system, I need thresholds that adapt to the noise floor so quiet environments don't get false positives.

**Acceptance Criteria:**
- [x] Replace hardcoded threshold (0.25) with adaptive calculation
- [x] Base threshold = `noiseFloor * 3.0 + 0.1` (minimum 0.1)
- [x] Ensure threshold is always above noise floor by significant margin
- [x] Add `minimumThreshold` parameter (default 0.15) - never go below this
- [x] Add unit test for threshold calculation with various noise floors
- [x] Typecheck passes

### US-008: Implement peak picking with temporal constraints
**Description:** As a system, I need peak picking that prevents multiple detections from the same drum hit.

**Acceptance Criteria:**
- [x] Add `_pickPeaks()` method that filters onset candidates
- [x] Require minimum 50ms between consecutive onsets (prevents doubles)
- [x] Only keep local maxima (spectral flux must decrease after peak)
- [x] Require peak to be 1.5x threshold (not just barely above)
- [x] Sort peaks by strength and keep only strongest candidates
- [x] Add unit test with synthetic peaks at various intervals
- [x] Typecheck passes

### US-009: Refactor analyzeRecording to use new pipeline
**Description:** As a developer, I need to integrate all new components into a coherent onset detection pipeline.

**Acceptance Criteria:**
- [ ] Update `analyzeRecording()` to use: noise floor → high-pass filter → spectral flux → adaptive threshold → peak picking
- [ ] Process audio in correct order: filter → FFT → flux → threshold → peaks
- [ ] Pass noise floor value through pipeline to adaptive threshold
- [ ] Maintain existing return type: `List<TapEvent>`
- [ ] Existing unit tests still compile (may fail until algorithm is tuned)
- [ ] Typecheck passes

### US-010: Add configuration parameters for tuning
**Description:** As a developer, I need easy access to tuning parameters so I can adjust sensitivity without changing code.

**Acceptance Criteria:**
- [ ] Add `OnsetDetectionConfig` class with parameters: `minimumThreshold`, `noiseFloorMultiplier`, `minPeakSeparationMs`, `peakStrengthMultiplier`, `highPassCutoffHz`
- [ ] Add default values that represent initial best guess
- [ ] Pass config object to `analyzeRecording()` method
- [ ] Update existing calls to use default config
- [ ] Document each parameter in code comments
- [ ] Typecheck passes

### US-011: Tune parameters to pass automated tests
**Description:** As a developer, I need to find parameter values that eliminate false positives while detecting real drum hits.

**Acceptance Criteria:**
- [ ] Adjust `OnsetDetectionConfig` defaults iteratively
- [ ] All tests in `rhythm_analyzer_false_positive_test.dart` pass
- [ ] Silence test: 0 detections
- [ ] Noise test: 0 detections
- [ ] Drum hits test: 7-9 detections (8 expected)
- [ ] Document final parameter values in code comments
- [ ] Typecheck passes

### US-012: Update Python diagnostic tools
**Description:** As a developer, I need updated Python analysis tools to validate the new algorithm against real recordings.

**Acceptance Criteria:**
- [ ] Update `quick_start_experiment/analyze_new_recordings.py` to show noise floor measurements
- [ ] Add visualization of adaptive threshold vs spectral flux
- [ ] Add peak picking visualization (detected onsets marked on plot)
- [ ] Compare old algorithm vs new algorithm side-by-side
- [ ] Add summary statistics: false positive rate, detection accuracy
- [ ] Update README with usage instructions

### US-013: Validate with real recordings and document results
**Description:** As a developer, I need to validate the new algorithm with real drum recordings and document performance.

**Acceptance Criteria:**
- [ ] Test with at least 3 real recordings: silence, background noise, actual drumming
- [ ] Run Python diagnostic tools on all recordings
- [ ] Document results in `CLAUDE_SESSION_LOG.md`: false positive rate, detection accuracy
- [ ] If accuracy < 95%, return to US-010 and retune parameters
- [ ] Create test report showing before/after comparison
- [ ] All existing integration tests pass
- [ ] Typecheck passes

## Non-Goals

- **No machine learning**: Keep algorithm deterministic and understandable
- **No cloud processing**: All onset detection remains on-device
- **No user-adjustable sensitivity**: Config parameters are developer-only (for MVP)
- **No support for non-drum sounds**: Algorithm optimized specifically for drum/percussion hits
- **No real-time visualization**: Debug output is post-processing only
- **No iOS support**: Android-only as per project constraints

## Technical Considerations

### Algorithm Research Foundation
The new onset detection pipeline is based on established music information retrieval (MIR) research:
- **Spectral Flux with HWR**: Half-wave rectified spectral flux (only count energy increases)
- **Frequency Weighting**: Focus on drum hit frequency range (200-4000 Hz)
- **Adaptive Thresholding**: Noise-relative thresholds prevent false positives
- **Peak Picking**: Temporal constraints and local maxima filtering
- **High-Pass Filtering**: Remove low-frequency noise before analysis

### Existing Code to Modify
- `lib/services/rhythm_analyzer.dart` - Main implementation target
- `test/services/rhythm_analyzer_diagnostic_test.dart` - May need updates
- `test/services/rhythm_analyzer_fast_drumming_test.dart` - Should still pass

### Dependencies
- Continue using `fftea: ^1.0.0` for FFT computation
- No new package dependencies required
- Python tools use existing `aubio`, `librosa`, `matplotlib`

### Performance Constraints
- Onset detection must complete in < 2 seconds for 60-second recording
- Process in background thread to avoid UI freezes
- Memory usage must stay under 50MB for audio processing

### Testing Strategy
1. **Automated tests** (US-003): Fast feedback loop during development
2. **Python diagnostic tools** (US-012): Visual analysis of algorithm behavior
3. **Manual testing** (US-013): Real-world validation with physical drum recordings

### Parameter Tuning Process
Start with these initial values (adjust in US-011 based on test results):
```dart
OnsetDetectionConfig(
  minimumThreshold: 0.15,
  noiseFloorMultiplier: 3.0,
  minPeakSeparationMs: 50,
  peakStrengthMultiplier: 1.5,
  highPassCutoffHz: 60.0,
)
```

### Rollback Plan
If new algorithm performs worse:
- Keep `rhythm_analyzer.dart` changes in feature branch
- Revert to baseline FFT implementation on main branch
- Use debug instrumentation to understand why new approach failed

## Success Metrics

**Primary Goal:** Zero false positives
- ✅ Silence recording: 0 detected beats
- ✅ Background noise recording: 0 detected beats

**Secondary Goal:** Maintain accuracy
- ✅ Real drum recording: ≥95% of actual hits detected
- ✅ Timing accuracy: ≤30ms average error

**Tertiary Goal:** Reliability
- ✅ All automated tests pass
- ✅ No crashes or performance degradation
- ✅ Works across different Android devices (tested on ≥2 devices)

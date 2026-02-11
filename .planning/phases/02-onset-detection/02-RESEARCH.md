# Phase 2: Onset Detection - Research

**Researched:** 2026-02-11
**Domain:** FFT-based spectral flux onset detection, beat matching, adaptive thresholding, fftea Dart library
**Confidence:** HIGH

## Summary

Phase 2 implements accurate onset detection from WAV recordings produced by Phase 1. A substantial `RhythmAnalyzer` implementation already exists in the codebase (383 lines) with FFT-based spectral flux detection, WAV loading, Hanning windowing, onset-to-beat matching, and bleed detection. However, the existing implementation has several weaknesses that must be addressed for the success criteria: (1) it hand-rolls the sliding-window FFT loop instead of using fftea's built-in STFT class, (2) it uses a fixed threshold that is normalized by previous-frame energy -- a reasonable approach but one that may struggle with varying volume levels across different recordings, (3) the minimum inter-onset interval (50ms) is too tight for high-BPM settings where beats are 300ms apart, and (4) there are no tests verifying detection accuracy across the full BPM range (40-200).

The existing test suite is a strong starting point: `rhythm_analyzer_test.dart`, `rhythm_analyzer_diagnostic_test.dart`, and `rhythm_analyzer_latency_test.dart` already verify basic detection with synthetic WAV files, silent audio rejection, edge cases, and latency compensation. The core algorithm structure (spectral flux with half-wave rectification) is sound. The main work is: refactoring to use fftea's STFT class, implementing adaptive thresholding with a moving-average approach for volume invariance, tuning parameters for the 40-200 BPM range, expanding the test suite with volume and BPM variations, and validating on a physical device with real recordings.

**Primary recommendation:** Refactor RhythmAnalyzer to use fftea's STFT class, add adaptive thresholding based on local moving average, and build a comprehensive synthetic test suite that validates detection accuracy across the BPM range (40-200) and amplitude range (soft to loud).

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **fftea** | ^1.0.0 (latest: 1.5.0+1) | FFT and STFT computation | Already in pubspec.yaml. Provides FFT, STFT with windowing, magnitudes extraction. Pure Dart, no native dependencies, works in tests without platform channels. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **dart:math** | (built-in) | sqrt, pi, cos, sin, pow | Mathematical operations for signal processing |
| **dart:io** | (built-in) | File I/O for WAV loading | Reading WAV files from disk |
| **dart:typed_data** | (built-in) | ByteData, Float64List, Float64x2List | Efficient numeric arrays for audio samples and FFT results |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| fftea STFT | Manual sliding window FFT (current code) | Current code works but duplicates what STFT.run() does. STFT.run() handles windowing, chunking, and iteration internally -- less code, fewer bugs. |
| Spectral flux | High-frequency content (HFC) | HFC is better for purely percussive onsets but less robust for mixed signals. Spectral flux is more general-purpose and already implemented. |
| Spectral flux | Complex domain onset detection | More accurate for pitched instruments but overkill for percussion/tapping. Adds implementation complexity. |

**No new dependencies needed.** All tools are already available.

## Architecture Patterns

### Recommended Project Structure

No new files needed. Phase 2 modifies existing files:

```
lib/services/
    rhythm_analyzer.dart       # REFACTOR - improve onset detection algorithm
test/services/
    rhythm_analyzer_test.dart  # EXPAND - add BPM range and volume tests
```

### Pattern 1: Use fftea STFT Instead of Manual Sliding Window

**What:** Replace the manual `for (int i = 0; i < samples.length - fftSize; i += hopSize)` loop with fftea's `STFT.run()` method, which handles windowing, chunking, and iteration.

**When to use:** Always. The existing code manually applies a Hanning window and iterates with hop size -- this is exactly what `STFT.run()` does internally with better-tested code.

**Example:**
```dart
// Source: https://pub.dev/packages/fftea (README example)
// BEFORE (current code - manual loop):
final fft = FFT(fftSize);
for (int i = 0; i < samples.length - fftSize; i += hopSize) {
  final window = samples.sublist(i, i + fftSize);
  final windowedSamples = _applyHanningWindow(window);
  final complexSpectrum = fft.realFft(windowedSamples);
  // ... extract magnitudes manually ...
}

// AFTER (using STFT):
final stft = STFT(fftSize, Window.hanning(fftSize));
final spectralFluxValues = <double>[];
List<double>? previousMagnitudes;

stft.run(samples, (Float64x2List freq) {
  final magnitudes = freq.discardConjugates().magnitudes();
  if (previousMagnitudes != null) {
    final flux = _calculateFlux(magnitudes, previousMagnitudes!);
    spectralFluxValues.add(flux);
  }
  previousMagnitudes = List<double>.from(magnitudes);
});
```

**Note:** fftea's STFT uses the chunk size as both the window size and hop size by default. To use a different hop size, the manual loop approach is needed OR use `STFT.stream()` with manual feeding. The existing code uses fftSize=2048 and hopSize=512 (4:1 ratio). Since fftea's STFT.run() does not expose a hop size parameter, the manual loop may need to stay but should still use Window.hanning for windowing. Verify fftea API for hop size support before committing to STFT.run().

### Pattern 2: Adaptive Thresholding with Moving Average

**What:** Instead of a single fixed threshold, compute a local moving average of the spectral flux curve and trigger an onset when the current value exceeds the average by a configurable multiplier. This handles varying recording volumes without manual threshold tuning per-recording.

**When to use:** Always. A fixed threshold fails when recording volume varies between sessions or within a session (soft vs loud taps). The current code normalizes flux by previous-frame energy, which helps but is not robust enough.

**Example:**
```dart
// Adaptive threshold: onset if flux[i] > mean(flux[i-w..i+w]) * multiplier + offset
// Parameters from literature (CPJKU onset_detection):
//   pre_avg = 100ms, post_avg = 30ms (offline)
//   multiplier (delta) = 1.5-3.0 (tune empirically)
//   offset = 0.01 (small constant to avoid noise triggers)
List<double> _adaptiveThreshold(List<double> fluxValues, {
  int preAvgFrames = 10,  // ~100ms at hopSize=512/44100Hz
  int postAvgFrames = 3,  // ~30ms
  double delta = 2.0,     // multiplier above local average
  double offset = 0.01,   // minimum threshold floor
}) {
  final thresholds = <double>[];
  for (int i = 0; i < fluxValues.length; i++) {
    final start = (i - preAvgFrames).clamp(0, fluxValues.length);
    final end = (i + postAvgFrames + 1).clamp(0, fluxValues.length);
    final window = fluxValues.sublist(start, end);
    final avg = window.reduce((a, b) => a + b) / window.length;
    thresholds.add(avg * delta + offset);
  }
  return thresholds;
}
```

### Pattern 3: Logarithmic Compression for Volume Invariance

**What:** Apply logarithmic compression to magnitude spectra before computing flux: `Y = log(1 + gamma * |X|)`. This makes the spectral flux measure relative magnitude changes rather than absolute differences, improving robustness across different tap volumes.

**When to use:** When detection must handle soft-to-loud tap range. The log compression reduces the dynamic range so that a soft clap produces a similar relative spectral change as a loud clap.

**Example:**
```dart
// Source: Fundamentals of Music Processing (Muller), Section C6
// gamma controls compression strength:
//   gamma = 1.0: mild compression
//   gamma = 10.0: moderate (recommended starting point)
//   gamma = 100.0: strong compression (good for wide volume range)
List<double> _logCompress(List<double> magnitudes, {double gamma = 10.0}) {
  return magnitudes.map((m) => log(1.0 + gamma * m)).toList();
}
```

### Pattern 4: BPM-Aware Minimum Inter-Onset Interval

**What:** Set the minimum time between detected onsets based on the BPM, not a fixed 50ms. At 200 BPM the beat interval is 300ms, so a minimum of ~150ms (half a beat) prevents spurious double-triggers without suppressing real beats. At 40 BPM (1500ms per beat) the minimum could be longer.

**When to use:** Always. The current 50ms minimum allows spurious onsets to be detected between real beats, especially at slower tempos where there is more silence between taps.

**Example:**
```dart
// Minimum inter-onset interval = half the beat interval or 50ms, whichever is larger
double _minOnsetInterval(int bpm) {
  final beatInterval = 60.0 / bpm;
  return max(0.05, beatInterval * 0.4); // 40% of beat interval, min 50ms
}
```

### Pattern 5: Peak Picking with Local Maximum Requirement

**What:** An onset is triggered only when the spectral flux value is both above the adaptive threshold AND is a local maximum (greater than its immediate neighbors). This prevents triggering on the rising edge of a broad spectral change.

**When to use:** Always. Without local maximum requirement, the algorithm may trigger multiple times on the rising edge of a single onset.

**Example:**
```dart
bool _isLocalMax(List<double> flux, int index) {
  if (index <= 0 || index >= flux.length - 1) return false;
  return flux[index] > flux[index - 1] && flux[index] > flux[index + 1];
}
```

### Anti-Patterns to Avoid

- **Fixed global threshold:** A single constant threshold (current: 0.12) cannot handle varying recording volumes. Use adaptive thresholding instead.
- **Testing only with synthetic data:** Synthetic impulses are sine bursts; real taps/claps have broadband energy. Tests establish baseline but device testing is essential.
- **Tuning threshold on one BPM:** A threshold tuned at 120 BPM may miss beats at 40 BPM (where spectral contrast is different due to longer silence gaps) or produce false positives at 200 BPM.
- **Removing the normalized flux approach entirely:** The current normalization-by-previous-energy approach has value. Combine it with adaptive thresholding rather than replacing it.
- **Using very small FFT sizes:** Smaller FFT (e.g., 512) gives better time resolution but worse frequency resolution. For onset detection of percussive sounds, 1024-2048 is the standard range. Keep 2048.
- **Ignoring the STFT hop size:** The 4:1 overlap (2048 window, 512 hop) gives ~11.6ms time resolution. This is appropriate. Do not increase hop size (would lose time resolution) or decrease it unnecessarily (would slow processing).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| FFT computation | Custom DFT | fftea `FFT` class | Already integrated, optimized, handles any array size |
| Hanning window | Manual cosine loop | fftea `Window.hanning()` | Already available in fftea, tested, correct |
| Complex number magnitudes | Manual sqrt(x^2 + y^2) | fftea `.magnitudes()` | Extension method on Float64x2List, optimized |
| WAV file parsing | Custom byte parser | Keep existing implementation | The current WAV parser works correctly and was validated in Phase 1. No need to change. |
| Metronome bleed detection | Statistical heuristic | Keep existing implementation | Current approach (consistency < 3.0ms) is well-reasoned and tested |

**Key insight:** The existing code already hand-rolls things that fftea provides (Hanning window, magnitude extraction). Replacing these with fftea built-ins reduces code and potential bugs. However, the manual sliding window loop may need to stay if fftea's STFT.run() does not support custom hop sizes.

## Common Pitfalls

### Pitfall 1: Fixed Threshold Fails Across Volume Levels

**What goes wrong:** Detection works for loud taps but misses soft taps, or detects background noise as onsets in quiet recordings.
**Why it happens:** A fixed spectral flux threshold is calibrated for one volume level. Recording volume depends on: tap force, distance to microphone, device microphone sensitivity, background noise.
**How to avoid:** Use adaptive thresholding where the threshold is computed as a function of the local spectral flux average. This makes the threshold relative to the signal's own energy level.
**Warning signs:** Detection rate drops below 50% for soft taps. False positives appear in quiet passages. Works perfectly with synthetic data but fails on real recordings.

### Pitfall 2: Over-Tuning on Synthetic Test Data

**What goes wrong:** Algorithm parameters work perfectly on synthetic sine-burst test WAVs but fail on real recordings from a phone microphone.
**Why it happens:** Synthetic sine bursts have perfect onset characteristics (instant attack, known frequency, no noise). Real claps/taps have: broadband spectral content, varying attack shapes, ambient noise, microphone coloration, room reflections.
**How to avoid:** Use synthetic tests only for establishing baselines and verifying algorithm structure. Final tuning MUST happen on physical device recordings. Create a set of reference recordings at different volumes and BPMs for regression testing.
**Warning signs:** All synthetic tests pass but real-world detection rate is poor.

### Pitfall 3: Double Detection at Slow BPMs

**What goes wrong:** At 40-60 BPM, the algorithm detects 2 onsets per actual tap because the spectral flux stays elevated for multiple frames after a broadband percussive hit.
**Why it happens:** A clap has a sharp attack but its energy rings out over 20-50ms. Multiple FFT frames see spectral energy increase. Without proper local-maximum peak picking and inter-onset suppression, each frame above threshold triggers an onset.
**How to avoid:** Implement local-maximum peak picking (onset must be greater than neighbors). Set BPM-aware minimum inter-onset interval. The current 50ms minimum helps but should be BPM-scaled.
**Warning signs:** Detected onset count is 2x the expected beat count. TapEvent errors cluster in pairs.

### Pitfall 4: Onset Timing Offset from FFT Windowing

**What goes wrong:** Detected onset times are consistently 20-30ms late compared to the actual attack time.
**Why it happens:** The FFT window centers the analysis. The current code uses `(i + fftSize / 2) / sampleRate` for timing, which places the onset at the center of the window. But spectral flux measures the CHANGE between frames, so the onset is actually between two windows, not at the center of one.
**How to avoid:** The onset time should be the midpoint between the current and previous frame positions: `(i + hopSize / 2) / sampleRate` -- but this introduces its own inaccuracies. The real answer is that FFT-based onset detection has inherent timing resolution limited by the hop size (~11.6ms at 512 hop/44100Hz). For a rhythm coaching app where errors of 10-50ms matter, this resolution is adequate but the systematic offset must be characterized and documented.
**Warning signs:** All TapEvent errors have a consistent positive bias (everything detected as slightly late).

### Pitfall 5: Catch Block Swallows Real Errors

**What goes wrong:** `analyzeAudio()` returns an empty list and gives no indication of what went wrong.
**Why it happens:** The current code wraps the entire method in try/catch and returns empty list on any error. This includes genuine bugs (index out of bounds, null pointer), not just expected failures (file not found, silent audio).
**How to avoid:** Let unexpected errors propagate. Only catch expected failure modes (file not found, audio too quiet) and return empty list for those. Re-throw unexpected errors so they surface during development and testing.
**Warning signs:** Tests pass (empty list) when they should fail. Bugs hide behind "no beats detected" message.

### Pitfall 6: Latency Offset Applied Incorrectly

**What goes wrong:** Calibrated latency makes timing worse instead of better, or causes onset times to go negative.
**Why it happens:** The latency offset sign convention is easy to get wrong. Currently the code subtracts the offset: `t - latencySeconds`. This assumes a positive offset means "the recording system added this much delay." If the sign is wrong, the correction doubles the error.
**How to avoid:** The existing latency test (`rhythm_analyzer_latency_test.dart`) validates the sign convention. Ensure this test continues to pass after any refactoring. Document the sign convention clearly in code comments.
**Warning signs:** After calibration, average error increases instead of decreasing.

## Code Examples

### Improved _detectOnsets with Adaptive Thresholding

```dart
// Source: Algorithm based on CPJKU onset_detection (https://github.com/CPJKU/onset_detection)
// and Fundamentals of Music Processing spectral novelty function
List<double> _detectOnsets(List<double> samples, int bpm) {
  final onsets = <double>[];
  if (samples.length < fftSize) return onsets;

  // Step 1: Compute spectral flux values for all frames
  final fft = FFT(fftSize);
  final fluxValues = <double>[];
  final frameTimes = <double>[];
  List<double>? previousMagnitudes;

  for (int i = 0; i <= samples.length - fftSize; i += hopSize) {
    final window = samples.sublist(i, i + fftSize);
    final windowedSamples = Window.hanning(fftSize).apply(window);
    final complexSpectrum = fft.realFft(windowedSamples);

    // Extract magnitudes and apply log compression
    final rawMagnitudes = <double>[];
    for (int j = 0; j < complexSpectrum.length; j++) {
      final real = complexSpectrum[j].x;
      final imag = complexSpectrum[j].y;
      rawMagnitudes.add(log(1.0 + 10.0 * sqrt(real * real + imag * imag)));
    }

    if (previousMagnitudes != null) {
      // Half-wave rectified spectral flux (only positive changes)
      double flux = 0.0;
      for (int j = 0; j < rawMagnitudes.length; j++) {
        final diff = rawMagnitudes[j] - previousMagnitudes![j];
        if (diff > 0) flux += diff;
      }
      fluxValues.add(flux);
      frameTimes.add((i + hopSize / 2) / sampleRate);
    }
    previousMagnitudes = rawMagnitudes;
  }

  if (fluxValues.isEmpty) return onsets;

  // Step 2: Compute adaptive threshold
  final thresholds = _adaptiveThreshold(fluxValues);

  // Step 3: Peak picking
  final minInterval = _minOnsetInterval(bpm);
  for (int i = 1; i < fluxValues.length - 1; i++) {
    if (fluxValues[i] > thresholds[i] &&
        fluxValues[i] > fluxValues[i - 1] &&
        fluxValues[i] > fluxValues[i + 1]) {
      final time = frameTimes[i];
      if (onsets.isEmpty || (time - onsets.last) > minInterval) {
        onsets.add(time);
      }
    }
  }

  return onsets;
}
```

### Synthetic Test WAV Generation Helper

```dart
// Source: Existing pattern from test/services/rhythm_analyzer_test.dart
// Enhanced with configurable amplitude for volume range testing
Future<void> createTestWavWithBeats(
  File file, {
  required int sampleRate,
  required int bpm,
  required int durationSeconds,
  double amplitude = 0.8,        // 0.0-1.0 scale
  double timingJitterMs = 0.0,   // Random jitter in ms
}) async {
  final beatInterval = 60.0 / bpm;
  final samples = List<int>.filled(sampleRate * durationSeconds, 0);
  final random = Random(42); // Fixed seed for reproducibility

  for (double beatTime = 0.0; beatTime < durationSeconds; beatTime += beatInterval) {
    // Add timing jitter if specified
    final jitter = timingJitterMs > 0
        ? (random.nextDouble() * 2 - 1) * timingJitterMs / 1000.0
        : 0.0;
    final sampleIndex = ((beatTime + jitter) * sampleRate).round();

    // Create broadband impulse (more realistic than pure sine)
    for (int i = 0; i < 200; i++) {
      if (sampleIndex + i < samples.length) {
        final envelope = 1.0 - (i / 200.0); // Linear decay
        final signal = amplitude * 32000 * envelope *
            sin(2 * pi * 800 * i / sampleRate);
        samples[sampleIndex + i] = signal.round();
      }
    }
  }

  await _createWavFile(file, samples, sampleRate);
}
```

### BPM Range Test Pattern

```dart
// Test detection across full BPM range
for (final bpm in [40, 60, 80, 100, 120, 140, 160, 180, 200]) {
  test('Should detect beats at $bpm BPM', () async {
    final testFile = File('${tempDir.path}/bpm_$bpm.wav');
    await createTestWavWithBeats(testFile,
      sampleRate: 44100, bpm: bpm, durationSeconds: 10);

    final analyzer = RhythmAnalyzer();
    final tapEvents = await analyzer.analyzeAudio(
      audioFilePath: testFile.path,
      bpm: bpm,
      durationSeconds: 10,
      checkBleed: false,
    );

    final expectedBeats = (10 * bpm / 60).floor();
    final detectionRate = tapEvents.length / expectedBeats;

    expect(detectionRate, greaterThanOrEqualTo(0.8),
        reason: 'Should detect >=80% of beats at $bpm BPM');
  });
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Fixed threshold spectral flux | Adaptive threshold with moving average | Standard since ~2010 (Dixon et al.) | Handles varying volume levels without manual tuning |
| Raw magnitude difference | Log-compressed magnitude difference | Standard since ~2012 (Boeck et al.) | Volume-invariant: same threshold works for soft and loud inputs |
| Manual FFT + window | fftea STFT class | fftea 1.0.0 (2023) | Less hand-rolled code, built-in windowing, tested FFT implementation |
| Pure spectral flux | SuperFlux (max-filtered spectral flux) | 2012 (Boeck & Widmer) | Suppresses vibrato and spectral modulations. May be overkill for percussion but is the current standard. |

**Not needed for this project:**
- **SuperFlux / ComplexFlux:** These advanced variants improve detection for pitched instruments with vibrato. For percussion/tapping onset detection, standard spectral flux with adaptive thresholding is sufficient.
- **Neural network onset detection:** State-of-the-art uses RNNs/CNNs for onset detection. Overkill for a rhythm coaching app with percussion-only input. Requires training data and model inference infrastructure.
- **Phase-based onset detection:** Uses FFT phase information for more precise timing. Adds complexity; spectral flux timing resolution (~11.6ms) is adequate for coaching feedback.

## Open Questions

1. **fftea STFT hop size support**
   - What we know: fftea's `STFT.run()` takes a chunk size and window. The existing code uses 2048 window / 512 hop (4:1 overlap).
   - What's unclear: Whether `STFT.run()` supports configuring a hop size different from the chunk size. The docs show `STFT(chunkSize, window)` but do not mention hop size. If not supported, the manual loop must stay.
   - Recommendation: Test `STFT.run()` behavior. If it only supports hop=chunkSize, keep the manual loop but use `Window.hanning()` for windowing instead of the hand-rolled function. LOW priority -- the manual loop works fine.

2. **Optimal gamma for log compression**
   - What we know: gamma = 10 is a standard starting point. Higher gamma (100) gives stronger compression for wider volume range.
   - What's unclear: What gamma works best for phone-microphone recordings of hand claps and table taps.
   - Recommendation: Start with gamma = 10. Test on device with soft and loud taps. Adjust if needed. Include gamma as a named constant for easy tuning.

3. **Adaptive threshold multiplier (delta) tuning**
   - What we know: Literature suggests delta = 2.0-3.0. CPJKU implementation uses 2.5 as default.
   - What's unclear: Best value for this app's input characteristics (phone microphone, claps/taps, background noise).
   - Recommendation: Start with delta = 2.0 (more sensitive). Test on device. If too many false positives, increase. If missing soft taps, decrease. Expose as a constant for iterative tuning.

4. **Timing accuracy of onset position calculation**
   - What we know: Current code uses `(i + fftSize / 2) / sampleRate`. This is the center of the FFT window. Spectral flux measures change between consecutive frames. The true onset is somewhere between frames.
   - What's unclear: Whether this systematic offset matters for coaching accuracy. At 512 hop / 44100 Hz, max timing uncertainty is ~11.6ms.
   - Recommendation: Keep current approach. 11.6ms timing resolution is adequate for coaching (users cannot distinguish errors smaller than ~20ms). Document the limitation.

5. **Existing error handling in analyzeAudio()**
   - What we know: The method catches all exceptions and returns empty list. This hides bugs during development.
   - What's unclear: Whether MetronomeBleedException should still be caught (currently it IS caught by the generic catch block, despite having its own exception class).
   - Recommendation: Re-throw MetronomeBleedException and unexpected errors. Only return empty list for file-not-found and audio-too-quiet cases.

## Sources

### Primary (HIGH confidence)
- [fftea package v1.5.0+1 on pub.dev](https://pub.dev/packages/fftea) -- FFT, STFT, Window.hanning, magnitudes(), discardConjugates() API
- [fftea GitHub repository](https://github.com/liamappelbe/fftea) -- API usage examples, STFT.run pattern
- [fftea changelog](https://github.com/liamappelbe/fftea/blob/main/CHANGELOG.md) -- Version history, STFT streaming API added in 1.4.0
- Existing codebase: `lib/services/rhythm_analyzer.dart` (383 lines) -- Current implementation baseline
- Existing codebase: `test/services/rhythm_analyzer_test.dart` -- Test patterns and synthetic WAV generation

### Secondary (MEDIUM confidence)
- [CPJKU onset_detection](https://github.com/CPJKU/onset_detection/blob/master/onset_program.py) -- Adaptive thresholding parameters (pre_avg=100ms, post_avg=30ms, delta=2.5, window=2048, combine=30ms)
- [Spectral flux Wikipedia](https://en.wikipedia.org/wiki/Spectral_flux) -- Definition, normalization, half-wave rectification
- [Essentia onset detection docs](https://essentia.upf.edu/reference/streaming_OnsetDetection.html) -- Algorithm descriptions, parameter guidance
- [madmom onset detection](https://madmom.readthedocs.io/en/v0.16/modules/features/onsets.html) -- SuperFlux, peak picking, adaptive threshold parameters
- [Fundamentals of Music Processing (Audiolabs-Erlangen)](https://www.audiolabs-erlangen.de/resources/MIR/FMP/C6/C6S1_NoveltySpectral.html) -- Log compression formula Y = log(1 + gamma * |X|), spectral novelty function theory

### Tertiary (LOW confidence)
- Optimal gamma value for phone microphone recordings -- needs empirical validation on device
- Adaptive threshold delta for clap/tap detection -- literature values may need adjustment for this use case
- fftea STFT.run() hop size behavior -- needs API testing to confirm

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- fftea already integrated, API verified from pub.dev docs and GitHub
- Architecture (algorithm): HIGH -- Spectral flux with adaptive thresholding is a well-established standard algorithm with decades of research. Implementation patterns verified from multiple academic and code sources.
- Architecture (fftea STFT usage): MEDIUM -- STFT.run() API confirmed from docs but hop size behavior needs verification
- Pitfalls: HIGH -- Pitfalls derived from analysis of existing code weaknesses, standard onset detection literature, and Phase 1 experience
- Parameter tuning (gamma, delta, threshold): MEDIUM -- Starting values from literature but empirical tuning on device is essential

**Research date:** 2026-02-11
**Valid until:** 2026-03-11 (stable algorithm domain, 30-day validity)

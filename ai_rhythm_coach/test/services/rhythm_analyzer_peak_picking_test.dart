import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RhythmAnalyzer Peak Picking Tests', () {
    // Helper function to duplicate the private _pickPeaks method for testing
    List<double> pickPeaksPublic(
      List<double> fluxValues, {
      required double threshold,
      double minPeakSeparationMs = 50.0,
      double peakStrengthMultiplier = 1.5,
      required int hopSize,
      required double sampleRate,
    }) {
      final peaks = <Map<String, double>>[];
      final strengthThreshold = threshold * peakStrengthMultiplier;

      // Find local maxima that exceed the strength threshold
      for (int i = 1; i < fluxValues.length - 1; i++) {
        final current = fluxValues[i];
        final previous = fluxValues[i - 1];
        final next = fluxValues[i + 1];

        // Check if this is a local maximum
        final isLocalMax = current > previous && current > next;

        // Check if peak exceeds strength threshold
        final isStrongEnough = current >= strengthThreshold;

        if (isLocalMax && isStrongEnough) {
          // Calculate time in seconds for this peak
          // Each frame is separated by hopSize samples
          final timeInSeconds = (i * hopSize) / sampleRate;

          peaks.add({
            'time': timeInSeconds,
            'strength': current,
          });
        }
      }

      // Sort peaks by strength (strongest first)
      peaks.sort((a, b) => (b['strength'] as double).compareTo(a['strength'] as double));

      // Filter peaks by minimum separation time
      final filteredPeaks = <double>[];
      final minSeparationSeconds = minPeakSeparationMs / 1000.0;

      for (final peak in peaks) {
        final peakTime = peak['time'] as double;

        // Check if this peak is far enough from all previously selected peaks
        bool isFarEnough = true;
        for (final selectedTime in filteredPeaks) {
          if ((peakTime - selectedTime).abs() < minSeparationSeconds) {
            isFarEnough = false;
            break;
          }
        }

        if (isFarEnough) {
          filteredPeaks.add(peakTime);
        }
      }

      // Sort by time (chronological order)
      filteredPeaks.sort();

      return filteredPeaks;
    }

    const int hopSize = 512;
    const double sampleRate = 44100;

    test('detects local maxima above strength threshold', () {
      // Create flux values with clear peaks separated by at least 50ms
      // At 44.1kHz with 512 hop size, each frame is ~11.6ms
      // So we need at least 5 frames between peaks (5 * 11.6ms = 58ms)
      // Pattern: [low, low, PEAK, low, low, low, low, low, PEAK, low]
      final fluxValues = [0.1, 0.2, 0.5, 0.2, 0.1, 0.1, 0.1, 0.2, 0.6, 0.15];
      final threshold = 0.2;
      final peakStrengthMultiplier = 1.5; // 0.2 * 1.5 = 0.3

      final peaks = pickPeaksPublic(
        fluxValues,
        threshold: threshold,
        peakStrengthMultiplier: peakStrengthMultiplier,
        hopSize: hopSize,
        sampleRate: sampleRate,
      );

      // Both peaks (0.5 at index 2 and 0.6 at index 8) exceed strength threshold of 0.3
      // They are 6 frames apart = ~69ms, which exceeds 50ms minimum
      expect(peaks.length, equals(2));

      // Verify peaks are in chronological order
      expect(peaks[0], lessThan(peaks[1]));
    });

    test('ignores peaks below strength threshold', () {
      // Create flux values with weak peaks
      final fluxValues = [0.1, 0.2, 0.25, 0.2, 0.1, 0.28, 0.15];
      final threshold = 0.2;
      final peakStrengthMultiplier = 1.5; // 0.2 * 1.5 = 0.3

      final peaks = pickPeaksPublic(
        fluxValues,
        threshold: threshold,
        peakStrengthMultiplier: peakStrengthMultiplier,
        hopSize: hopSize,
        sampleRate: sampleRate,
      );

      // Both peaks (0.25 and 0.28) are below strength threshold of 0.3
      expect(peaks.length, equals(0));
    });

    test('requires local maximum (peak must decrease after)', () {
      // Create flux values where value is high but not a local maximum
      // Pattern: [low, RISING, STILL RISING, high, high]
      final fluxValues = [0.1, 0.3, 0.4, 0.5, 0.5];
      final threshold = 0.2;
      final peakStrengthMultiplier = 1.5;

      final peaks = pickPeaksPublic(
        fluxValues,
        threshold: threshold,
        peakStrengthMultiplier: peakStrengthMultiplier,
        hopSize: hopSize,
        sampleRate: sampleRate,
      );

      // No local maximum found (values keep rising or stay flat)
      expect(peaks.length, equals(0));
    });

    test('enforces minimum separation between peaks', () {
      // Create flux values with peaks very close together
      // At 44.1kHz with 512 hop size, each frame is ~11.6ms apart
      // So 5 frames = ~58ms
      final fluxValues = [
        0.1, 0.2, 0.6, 0.2, 0.1, // Peak at index 2
        0.2, 0.5, 0.2, // Peak at index 6 (4 frames = ~46ms later, below 50ms threshold)
        0.1, 0.1,
      ];
      final threshold = 0.2;
      final peakStrengthMultiplier = 1.5;
      final minPeakSeparationMs = 50.0;

      final peaks = pickPeaksPublic(
        fluxValues,
        threshold: threshold,
        peakStrengthMultiplier: peakStrengthMultiplier,
        minPeakSeparationMs: minPeakSeparationMs,
        hopSize: hopSize,
        sampleRate: sampleRate,
      );

      // Only strongest peak should be kept (0.6 at index 2)
      expect(peaks.length, equals(1));
    });

    test('allows peaks separated by more than minimum time', () {
      // Create flux values with peaks far apart
      // 10 frames apart = ~116ms (well above 50ms threshold)
      final fluxValues = [
        0.1, 0.2, 0.6, 0.2, 0.1, // Peak at index 2
        0.1, 0.1, 0.1, 0.1, 0.1,
        0.1, 0.2, 0.5, 0.2, 0.1, // Peak at index 12 (10 frames later)
      ];
      final threshold = 0.2;
      final peakStrengthMultiplier = 1.5;
      final minPeakSeparationMs = 50.0;

      final peaks = pickPeaksPublic(
        fluxValues,
        threshold: threshold,
        peakStrengthMultiplier: peakStrengthMultiplier,
        minPeakSeparationMs: minPeakSeparationMs,
        hopSize: hopSize,
        sampleRate: sampleRate,
      );

      // Both peaks should be kept
      expect(peaks.length, equals(2));
      expect(peaks[1] - peaks[0], greaterThan(minPeakSeparationMs / 1000.0));
    });

    test('keeps strongest peaks when multiple candidates compete', () {
      // Create flux values with multiple peaks close together
      final fluxValues = [
        0.1, 0.2, 0.4, 0.2, 0.1, // Weak peak at index 2 (0.4)
        0.2, 0.7, 0.2, // Strong peak at index 6 (0.7) - very close
        0.1, 0.1,
      ];
      final threshold = 0.2;
      final peakStrengthMultiplier = 1.5;
      final minPeakSeparationMs = 50.0;

      final peaks = pickPeaksPublic(
        fluxValues,
        threshold: threshold,
        peakStrengthMultiplier: peakStrengthMultiplier,
        minPeakSeparationMs: minPeakSeparationMs,
        hopSize: hopSize,
        sampleRate: sampleRate,
      );

      // Only strongest peak (0.7) should be kept
      expect(peaks.length, equals(1));

      // Verify it's the stronger peak (at index 6)
      final expectedTime = (6 * hopSize) / sampleRate;
      expect(peaks[0], closeTo(expectedTime, 0.001));
    });

    test('handles empty flux values', () {
      final fluxValues = <double>[];
      final threshold = 0.2;

      final peaks = pickPeaksPublic(
        fluxValues,
        threshold: threshold,
        hopSize: hopSize,
        sampleRate: sampleRate,
      );

      expect(peaks.length, equals(0));
    });

    test('handles flux values with less than 3 elements', () {
      // Need at least 3 elements to detect local maximum (previous, current, next)
      final fluxValues = [0.5, 0.8];
      final threshold = 0.2;

      final peaks = pickPeaksPublic(
        fluxValues,
        threshold: threshold,
        hopSize: hopSize,
        sampleRate: sampleRate,
      );

      expect(peaks.length, equals(0));
    });

    test('calculates correct peak times in seconds', () {
      // Create a single clear peak
      final fluxValues = [0.1, 0.2, 0.6, 0.2, 0.1];
      final threshold = 0.2;
      final peakStrengthMultiplier = 1.5;

      final peaks = pickPeaksPublic(
        fluxValues,
        threshold: threshold,
        peakStrengthMultiplier: peakStrengthMultiplier,
        hopSize: hopSize,
        sampleRate: sampleRate,
      );

      expect(peaks.length, equals(1));

      // Peak at index 2: (2 * 512) / 44100 = ~0.0232 seconds
      final expectedTime = (2 * hopSize) / sampleRate;
      expect(peaks[0], closeTo(expectedTime, 0.0001));
    });

    test('respects custom minimum separation parameter', () {
      // Create peaks close together with custom separation threshold
      final fluxValues = [
        0.1, 0.2, 0.6, 0.2, 0.1, // Peak at index 2
        0.2, 0.5, 0.2, // Peak at index 6 (4 frames = ~46ms later)
        0.1, 0.1,
      ];
      final threshold = 0.2;
      final peakStrengthMultiplier = 1.5;
      final minPeakSeparationMs = 30.0; // Lower threshold

      final peaks = pickPeaksPublic(
        fluxValues,
        threshold: threshold,
        peakStrengthMultiplier: peakStrengthMultiplier,
        minPeakSeparationMs: minPeakSeparationMs,
        hopSize: hopSize,
        sampleRate: sampleRate,
      );

      // Both peaks should be kept with 30ms threshold
      expect(peaks.length, equals(2));
    });

    test('respects custom peak strength multiplier', () {
      // Create peaks with custom strength multiplier
      final fluxValues = [0.1, 0.2, 0.35, 0.2, 0.1];
      final threshold = 0.2;
      final peakStrengthMultiplier = 2.0; // 0.2 * 2.0 = 0.4

      final peaks = pickPeaksPublic(
        fluxValues,
        threshold: threshold,
        peakStrengthMultiplier: peakStrengthMultiplier,
        hopSize: hopSize,
        sampleRate: sampleRate,
      );

      // Peak of 0.35 is below strength threshold of 0.4
      expect(peaks.length, equals(0));

      // Now with a peak that exceeds the threshold
      final fluxValues2 = [0.1, 0.2, 0.45, 0.2, 0.1];
      final peaks2 = pickPeaksPublic(
        fluxValues2,
        threshold: threshold,
        peakStrengthMultiplier: peakStrengthMultiplier,
        hopSize: hopSize,
        sampleRate: sampleRate,
      );

      expect(peaks2.length, equals(1));
    });
  });
}

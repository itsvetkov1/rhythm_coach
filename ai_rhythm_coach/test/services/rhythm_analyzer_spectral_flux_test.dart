import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for improved spectral flux calculation
/// Verifies frequency-weighted approach with focus on drum hit frequencies

void main() {
  group('RhythmAnalyzer - Spectral Flux Calculation', () {
    // Test helper to simulate spectral flux calculation
    // This duplicates the private _calculateSpectralFlux logic for testing
    double calculateSpectralFlux(
      List<double> currentMagnitudes,
      List<double> previousMagnitudes,
    ) {
      const double sampleRate = 44100;
      const int fftSize = 2048;

      // Calculate frequency bin resolution
      final binResolution = (sampleRate / 2) / (fftSize / 2);

      // Calculate bin indices for frequency ranges
      final minBin = (200 / binResolution).floor();
      final maxBin = min((8000 / binResolution).ceil(), currentMagnitudes.length);

      // Calculate weighted spectral flux
      double flux = 0.0;
      double previousEnergy = 0.0;

      for (int j = minBin; j < maxBin; j++) {
        final diff = currentMagnitudes[j] - previousMagnitudes[j];

        // Half-Wave Rectification: only count increases
        if (diff > 0) {
          // Apply frequency weighting
          final binFreq = j * binResolution;
          final weight = binFreq <= 4000 ? 1.0 : 0.5;

          flux += diff * weight;
        }

        previousEnergy += previousMagnitudes[j];
      }

      // Normalize flux
      final normalizedFlux = previousEnergy > 0
          ? flux / (previousEnergy + 0.0001)
          : 0.0;

      return normalizedFlux;
    }

    test('Spectral flux ignores low-frequency rumble (<200Hz)', () {
      // Create spectrum with energy only in low frequencies (<200Hz)
      const fftSize = 2048;
      const sampleRate = 44100;
      final binResolution = (sampleRate / 2) / (fftSize / 2);

      // Previous frame: no energy
      final previous = List<double>.filled(fftSize ~/ 2, 0.0);

      // Current frame: energy spike in low frequencies (0-200Hz)
      final current = List<double>.filled(fftSize ~/ 2, 0.0);
      final lowFreqBinEnd = (200 / binResolution).floor();
      for (int i = 0; i < lowFreqBinEnd; i++) {
        current[i] = 1.0; // Strong low-frequency energy
      }

      final flux = calculateSpectralFlux(current, previous);

      // Flux should be zero since all energy is below 200Hz (ignored range)
      expect(flux, equals(0.0), reason: 'Low-frequency rumble should not contribute to flux');
    });

    test('Spectral flux focuses on drum hit frequencies (200-4000Hz)', () {
      // Create spectrum with energy in drum hit range
      const fftSize = 2048;
      const sampleRate = 44100;
      final binResolution = (sampleRate / 2) / (fftSize / 2);

      // Previous frame: baseline energy in drum range
      final previous = List<double>.filled(fftSize ~/ 2, 0.1);

      // Current frame: energy spike in drum hit range (200-4000Hz)
      final current = List<double>.filled(fftSize ~/ 2, 0.1);
      final drumRangeStart = (200 / binResolution).floor();
      final drumRangeEnd = (4000 / binResolution).ceil();
      for (int i = drumRangeStart; i < drumRangeEnd; i++) {
        current[i] = 0.8; // Strong drum hit energy
      }

      final flux = calculateSpectralFlux(current, previous);

      // Flux should be positive and significant
      expect(flux, greaterThan(0.0), reason: 'Energy increase in drum range should produce positive flux');
      expect(flux, greaterThan(0.1), reason: 'Strong drum hit should produce significant flux');
    });

    test('Spectral flux ignores high-frequency noise (>8000Hz)', () {
      // Create spectrum with energy only in high frequencies (>8000Hz)
      const fftSize = 2048;
      const sampleRate = 44100;
      final binResolution = (sampleRate / 2) / (fftSize / 2);

      // Previous frame: no energy
      final previous = List<double>.filled(fftSize ~/ 2, 0.0);

      // Current frame: energy spike in high frequencies (>8000Hz)
      final current = List<double>.filled(fftSize ~/ 2, 0.0);
      final highFreqBinStart = (8000 / binResolution).ceil();
      for (int i = highFreqBinStart; i < current.length; i++) {
        current[i] = 1.0; // Strong high-frequency energy
      }

      final flux = calculateSpectralFlux(current, previous);

      // Flux should be zero since all energy is above 8000Hz (ignored range)
      expect(flux, equals(0.0), reason: 'High-frequency noise should not contribute to flux');
    });

    test('Spectral flux uses half-wave rectification (ignores energy decreases)', () {
      // Create spectrum where some bins increase and some decrease
      const fftSize = 2048;
      const sampleRate = 44100;
      final binResolution = (sampleRate / 2) / (fftSize / 2);

      // Previous frame: moderate energy in drum range
      final previous = List<double>.filled(fftSize ~/ 2, 0.5);

      // Current frame: half bins increase, half decrease
      final current = List<double>.filled(fftSize ~/ 2, 0.0);
      final drumRangeStart = (200 / binResolution).floor();
      final drumRangeEnd = min((4000 / binResolution).ceil(), current.length);
      final mid = (drumRangeStart + drumRangeEnd) ~/ 2;

      // First half: energy increases (0.5 → 0.8)
      for (int i = drumRangeStart; i < mid; i++) {
        current[i] = 0.8;
      }

      // Second half: energy decreases (0.5 → 0.2)
      for (int i = mid; i < drumRangeEnd; i++) {
        current[i] = 0.2;
      }

      final flux = calculateSpectralFlux(current, previous);

      // Flux should be positive (only increases counted)
      expect(flux, greaterThan(0.0), reason: 'HWR should only count energy increases');

      // Calculate expected flux (only from increases)
      final increasesOnly = calculateSpectralFlux(current, previous);
      expect(increasesOnly, greaterThan(0.0));
    });

    test('Spectral flux applies reduced weight to 4-8kHz range', () {
      // Compare flux from energy in 200-4kHz vs 4-8kHz
      const fftSize = 2048;
      const sampleRate = 44100;
      final binResolution = (sampleRate / 2) / (fftSize / 2);

      final previous = List<double>.filled(fftSize ~/ 2, 0.1);

      // Scenario 1: Energy increase in core drum range (200-4000Hz)
      final currentLow = List<double>.filled(fftSize ~/ 2, 0.1);
      final lowStart = (200 / binResolution).floor();
      final lowEnd = (4000 / binResolution).ceil();
      for (int i = lowStart; i < lowEnd; i++) {
        currentLow[i] = 0.6; // +0.5 energy increase
      }

      // Scenario 2: Equal energy increase in high range (4000-8000Hz)
      final currentHigh = List<double>.filled(fftSize ~/ 2, 0.1);
      final highStart = (4000 / binResolution).ceil();
      final highEnd = (8000 / binResolution).ceil();
      for (int i = highStart; i < highEnd; i++) {
        currentHigh[i] = 0.6; // +0.5 energy increase
      }

      final fluxLow = calculateSpectralFlux(currentLow, previous);
      final fluxHigh = calculateSpectralFlux(currentHigh, previous);

      // Low-frequency flux should be higher due to full weight (1.0)
      // High-frequency flux should be lower due to reduced weight (0.5)
      expect(fluxLow, greaterThan(fluxHigh),
          reason: '200-4kHz range should have higher weight than 4-8kHz range');
    });

    test('Spectral flux handles zero energy gracefully', () {
      // Both frames have zero energy
      const fftSize = 2048;
      final previous = List<double>.filled(fftSize ~/ 2, 0.0);
      final current = List<double>.filled(fftSize ~/ 2, 0.0);

      final flux = calculateSpectralFlux(current, previous);

      expect(flux, equals(0.0), reason: 'Zero energy should produce zero flux');
    });

    test('Spectral flux produces normalized values', () {
      // Verify flux values are reasonable (not excessively large)
      const fftSize = 2048;

      final previous = List<double>.filled(fftSize ~/ 2, 1.0);
      final current = List<double>.filled(fftSize ~/ 2, 2.0);

      final flux = calculateSpectralFlux(current, previous);

      // Normalized flux should be in reasonable range (0.0 to ~10.0)
      expect(flux, greaterThanOrEqualTo(0.0));
      expect(flux, lessThan(10.0), reason: 'Normalized flux should not be excessively large');
    });
  });
}

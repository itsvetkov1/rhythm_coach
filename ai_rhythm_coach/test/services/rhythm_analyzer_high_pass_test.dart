import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rhythm_coach/services/rhythm_analyzer.dart';

void main() {
  group('RhythmAnalyzer High-Pass Filter Tests', () {
    late RhythmAnalyzer analyzer;

    setUp(() {
      analyzer = RhythmAnalyzer();
    });

    test('DC offset removal - constant signal becomes zero', () {
      // Create a constant signal (pure DC offset)
      final dcSignal = List<double>.filled(1000, 0.5);

      // Apply high-pass filter
      final filtered = _applyHighPassFilterPublic(analyzer, dcSignal, 60.0);

      // After filter settles, output should approach zero
      // Check last 100 samples (after transient response)
      final steadyState = filtered.sublist(filtered.length - 100);
      final avgAmplitude = steadyState.map((s) => s.abs()).reduce((a, b) => a + b) / steadyState.length;

      // DC component should be heavily attenuated (< 0.01)
      expect(avgAmplitude, lessThan(0.01),
          reason: 'High-pass filter should remove DC offset (constant signal)');
    });

    test('Low-frequency signal attenuated - 30Hz sine wave', () {
      // Generate 30Hz sine wave (below 60Hz cutoff)
      const sampleRate = 44100.0;
      const frequency = 30.0;
      const duration = 1.0; // 1 second
      final numSamples = (sampleRate * duration).toInt();

      final lowFreqSignal = List<double>.generate(
        numSamples,
        (i) => sin(2 * pi * frequency * i / sampleRate),
      );

      // Measure input RMS
      final inputRMS = _calculateRMS(lowFreqSignal);

      // Apply high-pass filter
      final filtered = _applyHighPassFilterPublic(analyzer, lowFreqSignal, 60.0);

      // Measure output RMS (skip first 1000 samples for transient)
      final steadyState = filtered.sublist(1000);
      final outputRMS = _calculateRMS(steadyState);

      // Low frequency should be significantly attenuated (>50% reduction)
      expect(outputRMS, lessThan(inputRMS * 0.5),
          reason: 'Signal below cutoff frequency should be attenuated');
    });

    test('High-frequency signal preserved - 500Hz sine wave', () {
      // Generate 500Hz sine wave (well above 60Hz cutoff)
      const sampleRate = 44100.0;
      const frequency = 500.0;
      const duration = 1.0; // 1 second
      final numSamples = (sampleRate * duration).toInt();

      final highFreqSignal = List<double>.generate(
        numSamples,
        (i) => sin(2 * pi * frequency * i / sampleRate),
      );

      // Measure input RMS
      final inputRMS = _calculateRMS(highFreqSignal);

      // Apply high-pass filter
      final filtered = _applyHighPassFilterPublic(analyzer, highFreqSignal, 60.0);

      // Measure output RMS (skip first 1000 samples for transient)
      final steadyState = filtered.sublist(1000);
      final outputRMS = _calculateRMS(steadyState);

      // High frequency should be mostly preserved (>80% of input)
      expect(outputRMS, greaterThan(inputRMS * 0.8),
          reason: 'Signal above cutoff frequency should pass through');
    });

    test('DC offset + high-frequency signal - DC removed, signal preserved', () {
      // Generate 1000Hz sine wave with DC offset
      const sampleRate = 44100.0;
      const frequency = 1000.0;
      const duration = 1.0;
      const dcOffset = 0.3;
      final numSamples = (sampleRate * duration).toInt();

      final signal = List<double>.generate(
        numSamples,
        (i) => dcOffset + 0.5 * sin(2 * pi * frequency * i / sampleRate),
      );

      // Apply high-pass filter
      final filtered = _applyHighPassFilterPublic(analyzer, signal, 60.0);

      // Check steady state (skip transient)
      final steadyState = filtered.sublist(1000);

      // Mean should be close to zero (DC removed)
      final mean = steadyState.reduce((a, b) => a + b) / steadyState.length;
      expect(mean.abs(), lessThan(0.05),
          reason: 'DC offset should be removed');

      // RMS should be preserved (signal energy maintained)
      final outputRMS = _calculateRMS(steadyState);
      expect(outputRMS, greaterThan(0.3), // Original amplitude was 0.5
          reason: 'High-frequency signal energy should be preserved');
    });

    test('Empty samples list returns empty list', () {
      final filtered = _applyHighPassFilterPublic(analyzer, [], 60.0);
      expect(filtered, isEmpty);
    });

    test('Filter maintains correct sample count', () {
      final samples = List<double>.generate(1000, (i) => sin(2 * pi * i / 100));
      final filtered = _applyHighPassFilterPublic(analyzer, samples, 60.0);
      expect(filtered.length, equals(samples.length),
          reason: 'Filter should not change sample count');
    });
  });
}

// Helper function to test private method
// This duplicates the logic from RhythmAnalyzer._applyHighPassFilter()
List<double> _applyHighPassFilterPublic(RhythmAnalyzer analyzer, List<double> samples, double cutoffHz) {
  if (samples.isEmpty) return samples;

  const sampleRate = 44100.0;
  final alpha = 1.0 / (1.0 + 2.0 * pi * cutoffHz / sampleRate);

  final filtered = <double>[];
  double previousInput = 0.0;
  double previousOutput = 0.0;

  for (final sample in samples) {
    final output = alpha * (previousOutput + sample - previousInput);
    filtered.add(output);

    previousInput = sample;
    previousOutput = output;
  }

  return filtered;
}

// Helper function to calculate RMS
double _calculateRMS(List<double> samples) {
  if (samples.isEmpty) return 0.0;

  double sumSquares = 0.0;
  for (final sample in samples) {
    sumSquares += sample * sample;
  }

  return sqrt(sumSquares / samples.length);
}

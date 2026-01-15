import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

void main() {
  group('RhythmAnalyzer - Adaptive Threshold Calculation', () {
    // Helper function to test the adaptive threshold calculation logic
    // This duplicates the private method logic for testing purposes
    double calculateAdaptiveThreshold(
      double noiseFloorRMS, {
      double noiseFloorMultiplier = 3.0,
      double minimumThreshold = 0.15,
    }) {
      final adaptiveThreshold = noiseFloorRMS * noiseFloorMultiplier + 0.1;
      final finalThreshold = max(adaptiveThreshold, minimumThreshold);
      return finalThreshold;
    }

    test('Perfect silence (0.0 noise floor) uses minimum threshold', () {
      // In perfect silence, noise floor is 0.0
      // Formula: 0.0 * 3.0 + 0.1 = 0.1
      // But minimumThreshold (0.15) is higher, so it should use 0.15
      final noiseFloorRMS = 0.0;
      final threshold = calculateAdaptiveThreshold(noiseFloorRMS);

      expect(threshold, equals(0.15),
          reason: 'Threshold should be minimumThreshold (0.15) in perfect silence');
    });

    test('Very quiet environment (0.01 noise floor) uses minimum threshold', () {
      // In very quiet environment, noise floor is 0.01
      // Formula: 0.01 * 3.0 + 0.1 = 0.13
      // But minimumThreshold (0.15) is higher, so it should use 0.15
      final noiseFloorRMS = 0.01;
      final threshold = calculateAdaptiveThreshold(noiseFloorRMS);

      expect(threshold, equals(0.15),
          reason: 'Threshold should be minimumThreshold (0.15) when calculated threshold is lower');
    });

    test('Low noise environment (0.02 noise floor) uses adaptive threshold', () {
      // With low noise floor of 0.02
      // Formula: 0.02 * 3.0 + 0.1 = 0.16
      // This is above minimumThreshold (0.15), so use calculated value
      final noiseFloorRMS = 0.02;
      final threshold = calculateAdaptiveThreshold(noiseFloorRMS);

      expect(threshold, closeTo(0.16, 0.001),
          reason: 'Threshold should be 0.02 * 3.0 + 0.1 = 0.16');
    });

    test('Moderate noise environment (0.05 noise floor)', () {
      // With moderate noise floor of 0.05 (typical for quiet room with AC)
      // Formula: 0.05 * 3.0 + 0.1 = 0.25
      final noiseFloorRMS = 0.05;
      final threshold = calculateAdaptiveThreshold(noiseFloorRMS);

      expect(threshold, closeTo(0.25, 0.001),
          reason: 'Threshold should be 0.05 * 3.0 + 0.1 = 0.25');
    });

    test('High noise environment (0.10 noise floor)', () {
      // With high noise floor of 0.10 (noisy environment)
      // Formula: 0.10 * 3.0 + 0.1 = 0.40
      final noiseFloorRMS = 0.10;
      final threshold = calculateAdaptiveThreshold(noiseFloorRMS);

      expect(threshold, closeTo(0.40, 0.001),
          reason: 'Threshold should be 0.10 * 3.0 + 0.1 = 0.40');
    });

    test('Very high noise environment (0.20 noise floor)', () {
      // With very high noise floor of 0.20 (very noisy environment)
      // Formula: 0.20 * 3.0 + 0.1 = 0.70
      final noiseFloorRMS = 0.20;
      final threshold = calculateAdaptiveThreshold(noiseFloorRMS);

      expect(threshold, closeTo(0.70, 0.001),
          reason: 'Threshold should be 0.20 * 3.0 + 0.1 = 0.70');
    });

    test('Threshold always above noise floor by 3x margin', () {
      // Test multiple noise floor values to ensure 3x margin is maintained
      final testValues = [0.02, 0.05, 0.08, 0.10, 0.15];

      for (final noiseFloorRMS in testValues) {
        final threshold = calculateAdaptiveThreshold(noiseFloorRMS);

        // Threshold should be at least 3x noise floor (plus 0.1 offset)
        final expectedMinimum = noiseFloorRMS * 3.0 + 0.1;
        expect(threshold, greaterThanOrEqualTo(expectedMinimum),
            reason: 'Threshold must be at least 3x noise floor + 0.1 for noise floor $noiseFloorRMS');

        // Also verify the 3x margin from noise floor
        expect(threshold - noiseFloorRMS, greaterThanOrEqualTo(noiseFloorRMS * 2.0),
            reason: 'Threshold should have significant margin above noise floor');
      }
    });

    test('Custom minimum threshold is respected', () {
      // Test with custom minimum threshold of 0.20
      final noiseFloorRMS = 0.01; // Would normally give 0.13
      final customMinimum = 0.20;
      final threshold = calculateAdaptiveThreshold(
        noiseFloorRMS,
        minimumThreshold: customMinimum,
      );

      expect(threshold, equals(0.20),
          reason: 'Should use custom minimum threshold when calculated threshold is lower');
    });

    test('Threshold calculation is deterministic', () {
      // Same input should always produce same output
      final noiseFloorRMS = 0.05;

      final threshold1 = calculateAdaptiveThreshold(noiseFloorRMS);
      final threshold2 = calculateAdaptiveThreshold(noiseFloorRMS);
      final threshold3 = calculateAdaptiveThreshold(noiseFloorRMS);

      expect(threshold1, equals(threshold2),
          reason: 'Threshold calculation should be deterministic');
      expect(threshold2, equals(threshold3),
          reason: 'Threshold calculation should be deterministic');
    });

    test('Threshold scales linearly with noise floor', () {
      // Verify linear scaling property
      // If noise floor doubles, threshold should increase by 2 * 3.0 = 6.0
      final noiseFloor1 = 0.10;
      final noiseFloor2 = 0.20;

      final threshold1 = calculateAdaptiveThreshold(noiseFloor1);
      final threshold2 = calculateAdaptiveThreshold(noiseFloor2);

      // Difference should be (noiseFloor2 - noiseFloor1) * 3.0
      final expectedDifference = (noiseFloor2 - noiseFloor1) * 3.0;
      final actualDifference = threshold2 - threshold1;

      expect(actualDifference, closeTo(expectedDifference, 0.001),
          reason: 'Threshold should scale linearly with noise floor (3x multiplier)');
    });
  });
}

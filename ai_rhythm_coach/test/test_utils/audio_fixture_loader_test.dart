import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'audio_fixture_loader.dart';

void main() {
  group('AudioFixtureLoader', () {
    test('can load test_silence.wav fixture', () async {
      final samples = await AudioFixtureLoader.loadTestAudioFixture('test_silence.wav');

      expect(samples.length, greaterThan(0));
      // Silence should have all samples near zero
      final maxAmplitude = samples.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
      expect(maxAmplitude, lessThan(0.01)); // Should be essentially zero
    });

    test('can load test_white_noise.wav fixture', () async {
      final samples = await AudioFixtureLoader.loadTestAudioFixture('test_white_noise.wav');

      expect(samples.length, greaterThan(0));
      // White noise should have non-zero samples
      final rms = _calculateRms(samples);
      expect(rms, greaterThan(0.01)); // Should have some energy
      expect(rms, lessThan(0.15)); // But not too much (target was ~0.05)
    });

    test('can load test_drum_hits.wav fixture', () async {
      final samples = await AudioFixtureLoader.loadTestAudioFixture('test_drum_hits.wav');

      expect(samples.length, greaterThan(0));
      // Drum hits should have significant energy peaks
      final maxAmplitude = samples.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
      expect(maxAmplitude, greaterThan(0.5)); // Should have strong peaks
    });

    test('throws FileSystemException for non-existent file', () {
      expect(
        () => AudioFixtureLoader.loadTestAudioFixture('non_existent.wav'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}

double _calculateRms(List<double> samples) {
  final sumSquares = samples.fold<double>(0.0, (sum, s) => sum + s * s);
  return sqrt(sumSquares / samples.length);
}

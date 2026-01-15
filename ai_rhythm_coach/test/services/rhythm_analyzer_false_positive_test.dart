import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rhythm_coach/services/rhythm_analyzer.dart';

void main() {
  group('RhythmAnalyzer False Positive Prevention Tests', () {
    late RhythmAnalyzer analyzer;

    setUp(() {
      analyzer = RhythmAnalyzer();
    });

    test('test_silence.wav should produce zero detected onsets', () async {
      // Path to the silent test fixture
      final testFile = 'test/fixtures/audio/test_silence.wav';

      // Analyze the silent audio file
      // We use a standard BPM and duration, but no beats should be detected
      final tapEvents = await analyzer.analyzeAudio(
        audioFilePath: testFile,
        bpm: 120,
        durationSeconds: 5,
        debugMode: true,
      );

      // Expected: Zero detections in complete silence
      // Current algorithm may FAIL this test (expected until onset detection is improved)
      expect(
        tapEvents.length,
        equals(0),
        reason: 'Complete silence should produce zero detected onsets. '
            'Detected ${tapEvents.length} false positives.',
      );
    });

    test('test_white_noise.wav should produce zero detected onsets', () async {
      // Path to the white noise test fixture
      final testFile = 'test/fixtures/audio/test_white_noise.wav';

      // Analyze the low-level white noise audio file
      // RMS ~0.05, should not trigger onset detection
      final tapEvents = await analyzer.analyzeAudio(
        audioFilePath: testFile,
        bpm: 120,
        durationSeconds: 5,
        debugMode: true,
      );

      // Expected: Zero detections from background noise
      // Current algorithm may FAIL this test (expected until onset detection is improved)
      expect(
        tapEvents.length,
        equals(0),
        reason: 'Low-level white noise (RMS ~0.05) should produce zero detected onsets. '
            'Detected ${tapEvents.length} false positives.',
      );
    });

    test('test_drum_hits.wav should detect exactly 8 onsets (±1 acceptable)', () async {
      // Path to the drum hits test fixture
      final testFile = 'test/fixtures/audio/test_drum_hits.wav';

      // Analyze the drum hits audio file
      // Contains 8 impulse hits at 120 BPM
      final tapEvents = await analyzer.analyzeAudio(
        audioFilePath: testFile,
        bpm: 120,
        durationSeconds: 5,
        debugMode: true,
      );

      // Expected: 7-9 detections (8 expected, ±1 acceptable)
      // This verifies that real drum hits are still detected accurately
      expect(
        tapEvents.length,
        inInclusiveRange(7, 9),
        reason: 'Should detect 8 drum hits (±1 acceptable). '
            'Detected ${tapEvents.length} onsets. '
            'Too few detections indicate the algorithm is too conservative. '
            'Too many detections indicate false positives or double-triggering.',
      );

      // Additional validation: Check that detected beats have reasonable timing
      if (tapEvents.isNotEmpty) {
        // At 120 BPM, beats should be 0.5 seconds apart
        const expectedBeatInterval = 0.5; // 60.0 / 120 BPM

        // Verify first beat is near the start (within first second)
        expect(
          tapEvents.first.actualTime,
          lessThan(1.0),
          reason: 'First drum hit should be detected near the start of the recording',
        );

        // Verify beats are roughly evenly spaced
        if (tapEvents.length >= 2) {
          final intervals = <double>[];
          for (int i = 1; i < tapEvents.length; i++) {
            final interval = tapEvents[i].actualTime - tapEvents[i - 1].actualTime;
            intervals.add(interval);
          }

          // Average interval should be close to expected beat interval (±50ms tolerance)
          final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
          expect(
            avgInterval,
            closeTo(expectedBeatInterval, 0.05),
            reason: 'Average interval between detected beats should be close to 0.5s '
                '(120 BPM). Found ${avgInterval.toStringAsFixed(3)}s',
          );
        }
      }
    });

    test('Print diagnostic summary for all test fixtures', () async {
      // This test provides a summary of detection behavior across all fixtures
      // Useful for understanding how the algorithm performs before/after improvements

      print('\n========== False Positive Detection Summary ==========');

      // Test silence
      final silenceFile = 'test/fixtures/audio/test_silence.wav';
      final silenceEvents = await analyzer.analyzeAudio(
        audioFilePath: silenceFile,
        bpm: 120,
        durationSeconds: 5,
        debugMode: false, // Disable verbose debug output for summary
      );
      print('Silence (test_silence.wav):        ${silenceEvents.length} detections (Expected: 0)');

      // Test white noise
      final noiseFile = 'test/fixtures/audio/test_white_noise.wav';
      final noiseEvents = await analyzer.analyzeAudio(
        audioFilePath: noiseFile,
        bpm: 120,
        durationSeconds: 5,
        debugMode: false,
      );
      print('White Noise (test_white_noise.wav): ${noiseEvents.length} detections (Expected: 0)');

      // Test drum hits
      final drumFile = 'test/fixtures/audio/test_drum_hits.wav';
      final drumEvents = await analyzer.analyzeAudio(
        audioFilePath: drumFile,
        bpm: 120,
        durationSeconds: 5,
        debugMode: false,
      );
      print('Drum Hits (test_drum_hits.wav):    ${drumEvents.length} detections (Expected: 8)');

      print('\nFalse Positive Rate:');
      final falsePositives = silenceEvents.length + noiseEvents.length;
      final totalNegativeSamples = 2; // silence + noise
      print('  Total false positives: $falsePositives detections from $totalNegativeSamples files');

      if (drumEvents.isNotEmpty) {
        final detectionAccuracy = (drumEvents.length / 8.0) * 100;
        print('  Drum hit detection accuracy: ${detectionAccuracy.toStringAsFixed(1)}%');
      }

      print('=====================================================\n');

      // This test always passes - it's for informational purposes only
      expect(true, isTrue);
    });
  });
}

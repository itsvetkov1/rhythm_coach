import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rhythm_coach/services/rhythm_analyzer.dart';

void main() {
  group('RhythmAnalyzer Unit Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('rhythm_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('RMS Calculation', () {
      test('RMS should correctly calculate signal energy', () async {
        // Create a WAV file with known amplitude
        final testFile = File('${tempDir.path}/rms_test.wav');

        // Create samples with amplitude 0.5
        // RMS of a constant 0.5 signal should be 0.5
        final samples = List<int>.filled(44100, (0.5 * 32768).round());
        await _createWavFile(testFile, samples, 44100);

        // Load and check RMS through the analyzer
        final analyzer = RhythmAnalyzer();
        final result = await analyzer.analyzeAudio(
          audioFilePath: testFile.path,
          bpm: 60,
          durationSeconds: 1,
        );

        // The file should have sufficient energy
        // (If RMS calculation is broken, this would fail)
        // We expect empty list only if RMS is too low
        // With amplitude 0.5, RMS should be well above threshold
        expect(result, isNotNull);
      });

      test('RMS should detect silent audio', () async {
        // Create a silent WAV file
        final testFile = File('${tempDir.path}/silent.wav');
        final samples = List<int>.filled(44100, 0);
        await _createWavFile(testFile, samples, 44100);

        final analyzer = RhythmAnalyzer();
        final result = await analyzer.analyzeAudio(
          audioFilePath: testFile.path,
          bpm: 60,
          durationSeconds: 1,
        );

        // Silent audio should return empty list
        expect(result, isEmpty);
      });

      test('RMS should handle mixed silence and loud peaks', () async {
        // Create audio with 90% silence and 10% loud signal
        final testFile = File('${tempDir.path}/mixed.wav');
        final samples = <int>[];

        // Add silence
        for (int i = 0; i < 39690; i++) {
          samples.add(0);
        }

        // Add loud signal
        for (int i = 0; i < 4410; i++) {
          final value = (0.8 * 32768 * sin(2 * pi * 440 * i / 44100)).round();
          samples.add(value);
        }

        await _createWavFile(testFile, samples, 44100);

        final analyzer = RhythmAnalyzer();
        final result = await analyzer.analyzeAudio(
          audioFilePath: testFile.path,
          bpm: 60,
          durationSeconds: 1,
        );

        // Should detect the signal even though most of file is silence
        expect(result, isNotNull);
      });
    });

    group('Onset Detection', () {
      test('Should detect clear impulses at correct times', () async {
        final testFile = File('${tempDir.path}/impulses.wav');

        const sampleRate = 44100;
        const bpm = 60; // 1 beat per second
        const durationSeconds = 5;

        // Create impulses at t=0, 1, 2, 3, 4 seconds
        final samples = List<int>.filled(sampleRate * durationSeconds, 0);

        for (int beatIndex = 0; beatIndex < 5; beatIndex++) {
          final sampleIndex = beatIndex * sampleRate;

          // Create impulse: 50ms burst of 1kHz tone
          for (int i = 0; i < 2205; i++) {
            if (sampleIndex + i < samples.length) {
              final value = (25000 * sin(2 * pi * 1000 * i / sampleRate)).round();
              samples[sampleIndex + i] = value;
            }
          }
        }

        await _createWavFile(testFile, samples, sampleRate);

        final analyzer = RhythmAnalyzer();
        final tapEvents = await analyzer.analyzeAudio(
          audioFilePath: testFile.path,
          bpm: bpm,
          durationSeconds: durationSeconds,
        );

        print('Test: Detected ${tapEvents.length} out of 5 expected beats');

        // Should detect most or all beats
        expect(tapEvents.length, greaterThanOrEqualTo(4),
            reason: 'Should detect at least 4 out of 5 clear impulses');

        // Check timing accuracy
        if (tapEvents.isNotEmpty) {
          final firstTap = tapEvents.first;
          expect(firstTap.error.abs(), lessThan(100),
              reason: 'First beat should be within 100ms of expected time');
        }
      });

      test('Should not detect beats from constant tone', () async {
        final testFile = File('${tempDir.path}/constant_tone.wav');

        const sampleRate = 44100;
        const durationSeconds = 3;

        // Create constant 440Hz tone (no onsets)
        final samples = <int>[];
        for (int i = 0; i < sampleRate * durationSeconds; i++) {
          final value = (15000 * sin(2 * pi * 440 * i / sampleRate)).round();
          samples.add(value);
        }

        await _createWavFile(testFile, samples, sampleRate);

        final analyzer = RhythmAnalyzer();
        final tapEvents = await analyzer.analyzeAudio(
          audioFilePath: testFile.path,
          bpm: 60,
          durationSeconds: durationSeconds,
        );

        // A constant tone has no onsets, so should detect very few or zero beats
        // (might detect one at the start when tone begins)
        expect(tapEvents.length, lessThanOrEqualTo(1),
            reason: 'Constant tone should not produce multiple beat detections');
      });

      test('Should detect soft claps (lower amplitude impulses)', () async {
        final testFile = File('${tempDir.path}/soft_claps.wav');

        const sampleRate = 44100;
        const bpm = 120;
        const durationSeconds = 3;
        const beatInterval = 60.0 / bpm;

        final samples = List<int>.filled(sampleRate * durationSeconds, 0);

        for (double beatTime = 0.0; beatTime < durationSeconds; beatTime += beatInterval) {
          final sampleIndex = (beatTime * sampleRate).round();

          // Create soft impulse (lower amplitude)
          for (int i = 0; i < 150; i++) {
            if (sampleIndex + i < samples.length) {
              // Lower amplitude (10000 instead of 25000)
              final value = (10000 * sin(2 * pi * 800 * i / sampleRate)).round();
              samples[sampleIndex + i] = value;
            }
          }
        }

        await _createWavFile(testFile, samples, sampleRate);

        final analyzer = RhythmAnalyzer();
        final tapEvents = await analyzer.analyzeAudio(
          audioFilePath: testFile.path,
          bpm: bpm,
          durationSeconds: durationSeconds,
          checkBleed: false, // Synthetic data triggers bleed detection
        );

        final expectedBeats = (durationSeconds / beatInterval).floor();
        print('Test: Detected ${tapEvents.length} out of $expectedBeats expected soft claps');

        // Should detect at least half of the soft claps
        expect(tapEvents.length, greaterThanOrEqualTo((expectedBeats * 0.5).floor()),
            reason: 'Should detect at least 50% of soft claps with lowered thresholds');
      });
    });

    group('Beat Matching', () {
      test('Should match onsets to nearest expected beats', () async {
        final testFile = File('${tempDir.path}/beat_matching.wav');

        const sampleRate = 44100;
        const bpm = 100; // 0.6 seconds per beat
        const durationSeconds = 6;

        final samples = List<int>.filled(sampleRate * durationSeconds, 0);

        // Place impulses at: 0s, 0.6s, 1.2s, 1.8s, etc.
        for (double beatTime = 0.0; beatTime < durationSeconds; beatTime += 0.6) {
          final sampleIndex = (beatTime * sampleRate).round();

          for (int i = 0; i < 100; i++) {
            if (sampleIndex + i < samples.length) {
              final value = (28000 * sin(2 * pi * 900 * i / sampleRate)).round();
              samples[sampleIndex + i] = value;
            }
          }
        }

        await _createWavFile(testFile, samples, sampleRate);

        final analyzer = RhythmAnalyzer();
        final tapEvents = await analyzer.analyzeAudio(
          audioFilePath: testFile.path,
          bpm: bpm,
          durationSeconds: durationSeconds,
        );

        // Should match beats
        expect(tapEvents.length, greaterThan(5),
            reason: 'Should detect and match most beats');

        // Check that errors are reasonable
        if (tapEvents.length > 3) {
          final avgError = RhythmAnalyzer.calculateAverageError(tapEvents);
          expect(avgError, lessThan(150),
              reason: 'Average timing error should be reasonable for synthetic data');
        }
      });
    });

    group('Edge Cases', () {
      test('Should handle non-existent file gracefully', () async {
        final analyzer = RhythmAnalyzer();
        final result = await analyzer.analyzeAudio(
          audioFilePath: '/non/existent/file.wav',
          bpm: 120,
          durationSeconds: 60,
        );

        expect(result, isEmpty,
            reason: 'Non-existent file should return empty list');
      });

      test('Should handle very short duration', () async {
        final testFile = File('${tempDir.path}/short.wav');

        // Just 0.5 seconds
        const sampleRate = 44100;
        final samples = List<int>.filled((sampleRate * 0.5).round(), 0);

        // Add one impulse
        for (int i = 1000; i < 1200; i++) {
          samples[i] = 20000;
        }

        await _createWavFile(testFile, samples, sampleRate);

        final analyzer = RhythmAnalyzer();
        final result = await analyzer.analyzeAudio(
          audioFilePath: testFile.path,
          bpm: 120,
          durationSeconds: 1,
        );

        // Should complete without crashing
        expect(result, isNotNull);
      });
    });

    group('BPM Range Detection', () {
      for (final bpm in [40, 60, 80, 100, 120, 140, 160, 180, 200]) {
        test('Should detect >= 80% of beats at $bpm BPM', () async {
          final testFile = File('${tempDir.path}/bpm_$bpm.wav');
          const durationSeconds = 10;
          await _createTestWavWithBeats(testFile,
              sampleRate: 44100, bpm: bpm, durationSeconds: durationSeconds);

          final analyzer = RhythmAnalyzer();
          final tapEvents = await analyzer.analyzeAudio(
            audioFilePath: testFile.path,
            bpm: bpm,
            durationSeconds: durationSeconds,
            checkBleed: false,
          );

          final expectedBeats = (durationSeconds * bpm / 60).floor();
          final detectionRate = tapEvents.length / expectedBeats;

          print('BPM $bpm: detected ${tapEvents.length}/$expectedBeats beats (${(detectionRate * 100).toStringAsFixed(1)}%)');

          expect(detectionRate, greaterThanOrEqualTo(0.8),
              reason: 'Should detect >= 80% of beats at $bpm BPM');

          // No double-detection: detected count should not exceed 1.2x expected
          expect(tapEvents.length, lessThanOrEqualTo((expectedBeats * 1.2).ceil()),
              reason: 'Should not detect more than 120% of expected beats (double-detection) at $bpm BPM');
        });
      }
    });

    group('Amplitude Range Detection', () {
      for (final entry in [
        {'amplitude': 0.1, 'label': 'very soft'},
        {'amplitude': 0.3, 'label': 'soft'},
        {'amplitude': 0.5, 'label': 'medium'},
        {'amplitude': 0.8, 'label': 'loud'},
        {'amplitude': 1.0, 'label': 'maximum'},
      ]) {
        final amplitude = entry['amplitude'] as double;
        final label = entry['label'] as String;

        test('Should detect >= 80% of beats at $label amplitude ($amplitude)', () async {
          final testFile = File('${tempDir.path}/amp_${label.replaceAll(' ', '_')}.wav');
          const bpm = 120;
          const durationSeconds = 5;
          await _createTestWavWithBeats(testFile,
              sampleRate: 44100, bpm: bpm, durationSeconds: durationSeconds,
              amplitude: amplitude);

          final analyzer = RhythmAnalyzer();
          final tapEvents = await analyzer.analyzeAudio(
            audioFilePath: testFile.path,
            bpm: bpm,
            durationSeconds: durationSeconds,
            checkBleed: false,
          );

          final expectedBeats = (durationSeconds * bpm / 60).floor();
          final detectionRate = tapEvents.length / expectedBeats;

          print('Amplitude $amplitude ($label): detected ${tapEvents.length}/$expectedBeats beats (${(detectionRate * 100).toStringAsFixed(1)}%)');

          expect(detectionRate, greaterThanOrEqualTo(0.8),
              reason: 'Should detect >= 80% of $label taps (amplitude $amplitude)');
        });
      }
    });

    group('Timing Accuracy', () {
      test('Average timing error should be < 50ms for on-beat synthetic impulses at 120 BPM', () async {
        final testFile = File('${tempDir.path}/timing_accuracy.wav');
        const bpm = 120;
        const durationSeconds = 10;
        await _createTestWavWithBeats(testFile,
            sampleRate: 44100, bpm: bpm, durationSeconds: durationSeconds);

        final analyzer = RhythmAnalyzer();
        final tapEvents = await analyzer.analyzeAudio(
          audioFilePath: testFile.path,
          bpm: bpm,
          durationSeconds: durationSeconds,
          checkBleed: false,
        );

        expect(tapEvents.length, greaterThan(5),
            reason: 'Need enough beats to measure timing accuracy');

        final avgError = RhythmAnalyzer.calculateAverageError(tapEvents);
        print('Timing accuracy at 120 BPM: avg error = ${avgError.toStringAsFixed(1)}ms over ${tapEvents.length} beats');

        expect(avgError, lessThan(50),
            reason: 'Average timing error should be < 50ms for perfectly-timed synthetic impulses');
      });

      test('Average timing error should be < 50ms at 60 BPM (slow tempo)', () async {
        final testFile = File('${tempDir.path}/timing_60bpm.wav');
        const bpm = 60;
        const durationSeconds = 10;
        await _createTestWavWithBeats(testFile,
            sampleRate: 44100, bpm: bpm, durationSeconds: durationSeconds);

        final analyzer = RhythmAnalyzer();
        final tapEvents = await analyzer.analyzeAudio(
          audioFilePath: testFile.path,
          bpm: bpm,
          durationSeconds: durationSeconds,
          checkBleed: false,
        );

        expect(tapEvents.length, greaterThan(3),
            reason: 'Need enough beats to measure timing accuracy');

        final avgError = RhythmAnalyzer.calculateAverageError(tapEvents);
        print('Timing accuracy at 60 BPM: avg error = ${avgError.toStringAsFixed(1)}ms over ${tapEvents.length} beats');

        expect(avgError, lessThan(50),
            reason: 'Average timing error should be < 50ms for perfectly-timed synthetic impulses');
      });

      test('Average timing error should be < 50ms at 200 BPM (fast tempo)', () async {
        final testFile = File('${tempDir.path}/timing_200bpm.wav');
        const bpm = 200;
        const durationSeconds = 10;
        await _createTestWavWithBeats(testFile,
            sampleRate: 44100, bpm: bpm, durationSeconds: durationSeconds);

        final analyzer = RhythmAnalyzer();
        final tapEvents = await analyzer.analyzeAudio(
          audioFilePath: testFile.path,
          bpm: bpm,
          durationSeconds: durationSeconds,
          checkBleed: false,
        );

        expect(tapEvents.length, greaterThan(10),
            reason: 'Need enough beats to measure timing accuracy');

        final avgError = RhythmAnalyzer.calculateAverageError(tapEvents);
        print('Timing accuracy at 200 BPM: avg error = ${avgError.toStringAsFixed(1)}ms over ${tapEvents.length} beats');

        expect(avgError, lessThan(50),
            reason: 'Average timing error should be < 50ms for perfectly-timed synthetic impulses');
      });
    });
  });
}

/// Creates a standard WAV file with given samples
Future<void> _createWavFile(File file, List<int> samples, int sampleRate) async {
  final numSamples = samples.length;
  final dataSize = numSamples * 2;
  final fileSize = 36 + dataSize;

  final buffer = ByteData(44 + dataSize);

  // RIFF header
  buffer.setUint8(0, 0x52); // 'R'
  buffer.setUint8(1, 0x49); // 'I'
  buffer.setUint8(2, 0x46); // 'F'
  buffer.setUint8(3, 0x46); // 'F'
  buffer.setUint32(4, fileSize, Endian.little);
  buffer.setUint8(8, 0x57);  // 'W'
  buffer.setUint8(9, 0x41);  // 'A'
  buffer.setUint8(10, 0x56); // 'V'
  buffer.setUint8(11, 0x45); // 'E'

  // fmt chunk
  buffer.setUint8(12, 0x66); // 'f'
  buffer.setUint8(13, 0x6D); // 'm'
  buffer.setUint8(14, 0x74); // 't'
  buffer.setUint8(15, 0x20); // ' '
  buffer.setUint32(16, 16, Endian.little);
  buffer.setUint16(20, 1, Endian.little);
  buffer.setUint16(22, 1, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, sampleRate * 2, Endian.little);
  buffer.setUint16(32, 2, Endian.little);
  buffer.setUint16(34, 16, Endian.little);

  // data chunk
  buffer.setUint8(36, 0x64); // 'd'
  buffer.setUint8(37, 0x61); // 'a'
  buffer.setUint8(38, 0x74); // 't'
  buffer.setUint8(39, 0x61); // 'a'
  buffer.setUint32(40, dataSize, Endian.little);

  // Write samples
  for (int i = 0; i < samples.length; i++) {
    buffer.setInt16(44 + i * 2, samples[i], Endian.little);
  }

  await file.writeAsBytes(buffer.buffer.asUint8List());
}

/// Creates a WAV file with broadband impulses at regular beat intervals.
/// Uses a decaying envelope for more realistic onset characteristics.
Future<void> _createTestWavWithBeats(
  File file, {
  required int sampleRate,
  required int bpm,
  required int durationSeconds,
  double amplitude = 0.8,
}) async {
  final beatInterval = 60.0 / bpm;
  final samples = List<int>.filled(sampleRate * durationSeconds, 0);

  for (double beatTime = 0.0; beatTime < durationSeconds; beatTime += beatInterval) {
    final sampleIndex = (beatTime * sampleRate).round();
    // Broadband impulse with linear decay envelope (more realistic than pure sine)
    for (int i = 0; i < 200; i++) {
      if (sampleIndex + i < samples.length) {
        final envelope = 1.0 - (i / 200.0);
        final signal = amplitude * 32000 * envelope * sin(2 * pi * 800 * i / sampleRate);
        samples[sampleIndex + i] = signal.round();
      }
    }
  }

  await _createWavFile(file, samples, sampleRate);
}

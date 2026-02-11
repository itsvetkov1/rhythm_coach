import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rhythm_coach/services/rhythm_analyzer.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  group('RhythmAnalyzer Diagnostic Tests', () {
    late Directory tempDir;

    setUp(() async {
      // Create a temporary directory for test files
      tempDir = Directory.systemTemp.createTempSync('rhythm_test_');
    });

    tearDown(() async {
      // Clean up test files
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Should detect beats from synthetic WAV file with clear impulses', () async {
      // Create a synthetic WAV file with clear impulses at 120 BPM
      final testFile = File('${tempDir.path}/test_beats.wav');

      const sampleRate = 44100;
      const bpm = 120;
      const durationSeconds = 5; // Short 5-second test
      const beatInterval = 60.0 / bpm; // 0.5 seconds

      // Generate audio samples with clear impulses (claps)
      final samples = List<int>.filled(sampleRate * durationSeconds, 0);

      // Add impulses at each beat time
      for (double beatTime = 0; beatTime < durationSeconds; beatTime += beatInterval) {
        final sampleIndex = (beatTime * sampleRate).round();

        // Create an impulse: short burst of high amplitude samples (simulating a clap)
        for (int i = 0; i < 100; i++) {
          if (sampleIndex + i < samples.length) {
            // Sine wave burst at 1000 Hz for 2.3ms
            final amplitude = 20000; // High amplitude
            final frequency = 1000.0;
            final value = (amplitude * sin(2 * pi * frequency * i / sampleRate)).round();
            samples[sampleIndex + i] = value;
          }
        }
      }

      // Create WAV file
      await _createWavFile(testFile, samples, sampleRate);

      print('Created test WAV file: ${testFile.path}');
      print('File size: ${await testFile.length()} bytes');
      print('Expected beats: ${(durationSeconds / beatInterval).floor()}');

      // Analyze the file
      final analyzer = RhythmAnalyzer();
      final tapEvents = await analyzer.analyzeAudio(
        audioFilePath: testFile.path,
        bpm: bpm,
        durationSeconds: durationSeconds,
      );

      print('Detected tap events: ${tapEvents.length}');

      // Should detect most of the beats (allow for some margin)
      final expectedBeats = (durationSeconds / beatInterval).floor();
      expect(tapEvents.length, greaterThan(expectedBeats - 2),
          reason: 'Should detect most beats. Expected ~$expectedBeats, got ${tapEvents.length}');

      // Check that detected beats are close to expected times
      if (tapEvents.isNotEmpty) {
        final firstTap = tapEvents.first;
        expect(firstTap.actualTime, lessThan(1.0),
            reason: 'First beat should be near the start');

        print('First tap: actual=${firstTap.actualTime.toStringAsFixed(3)}s, '
              'expected=${firstTap.expectedTime.toStringAsFixed(3)}s, '
              'error=${firstTap.error.toStringAsFixed(1)}ms');
      }
    });

    test('Should return empty list for silent audio file', () async {
      // Create a silent WAV file
      final testFile = File('${tempDir.path}/silent.wav');

      const sampleRate = 44100;
      const durationSeconds = 2;

      // All zeros (silence)
      final samples = List<int>.filled(sampleRate * durationSeconds, 0);
      await _createWavFile(testFile, samples, sampleRate);

      final analyzer = RhythmAnalyzer();
      final tapEvents = await analyzer.analyzeAudio(
        audioFilePath: testFile.path,
        bpm: 120,
        durationSeconds: durationSeconds,
      );

      print('Tap events from silent file: ${tapEvents.length}');
      expect(tapEvents, isEmpty,
          reason: 'Silent audio should produce no detected beats');
    });

    test('Should read WAV file samples correctly', () async {
      // Create a simple WAV file with known values
      final testFile = File('${tempDir.path}/test_samples.wav');

      const sampleRate = 44100;

      // Create samples with known pattern
      final samples = <int>[];
      for (int i = 0; i < 1000; i++) {
        // Create a simple sine wave
        final value = (16000 * sin(2 * pi * 440 * i / sampleRate)).round();
        samples.add(value);
      }

      await _createWavFile(testFile, samples, sampleRate);

      print('Created test file with ${samples.length} samples');
      print('File size: ${await testFile.length()} bytes');

      // Read the file back
      final bytes = await testFile.readAsBytes();
      print('File has ${bytes.length} bytes');
      print('First 60 bytes (header + start): ${bytes.take(60).toList()}');

      // Parse samples manually (same logic as RhythmAnalyzer)
      final parsedSamples = <double>[];
      const startIndex = 44; // WAV header size

      for (int i = startIndex; i < bytes.length - 1; i += 2) {
        final sample = (bytes[i] | (bytes[i + 1] << 8));
        final signed = sample > 32767 ? sample - 65536 : sample;
        final normalized = signed / 32768.0;
        parsedSamples.add(normalized);
      }

      print('Parsed ${parsedSamples.length} samples');
      print('Original samples: ${samples.take(10).toList()}');
      print('Parsed samples (first 10, denormalized): ${parsedSamples.take(10).map((s) => (s * 32768).round()).toList()}');

      expect(parsedSamples.length, greaterThan(900),
          reason: 'Should parse most samples');
    });

    test('Should detect very loud claps', () async {
      // Create a WAV file with extremely loud impulses
      final testFile = File('${tempDir.path}/loud_claps.wav');

      const sampleRate = 44100;
      const bpm = 120;
      const durationSeconds = 3;
      const beatInterval = 60.0 / bpm;

      // Generate samples with VERY loud impulses
      final samples = List<int>.filled(sampleRate * durationSeconds, 0);

      for (double beatTime = 0.0; beatTime < durationSeconds; beatTime += beatInterval) {
        final sampleIndex = (beatTime * sampleRate).round();

        // Create an extremely loud impulse
        for (int i = 0; i < 200; i++) {
          if (sampleIndex + i < samples.length) {
            // Maximum amplitude
            final amplitude = 32000; // Near maximum for 16-bit
            final frequency = 800.0; // Lower frequency for clap
            final value = (amplitude * sin(2 * pi * frequency * i / sampleRate)).round();
            samples[sampleIndex + i] = value;
          }
        }
      }

      await _createWavFile(testFile, samples, sampleRate);

      print('Created loud claps test file');

      final analyzer = RhythmAnalyzer();
      final tapEvents = await analyzer.analyzeAudio(
        audioFilePath: testFile.path,
        bpm: bpm,
        durationSeconds: durationSeconds,
        checkBleed: false, // Synthetic data triggers bleed detection
      );

      print('Detected ${tapEvents.length} claps');

      final expectedBeats = (durationSeconds / beatInterval).floor();
      expect(tapEvents.length, greaterThanOrEqualTo(expectedBeats - 1),
          reason: 'Should detect loud claps clearly');
    });
  });
}

/// Creates a standard WAV file with given samples
Future<void> _createWavFile(File file, List<int> samples, int sampleRate) async {
  // WAV file format:
  // - RIFF header (12 bytes)
  // - fmt chunk (24 bytes)
  // - data chunk header (8 bytes)
  // - audio data (samples * 2 bytes)

  final numSamples = samples.length;
  final dataSize = numSamples * 2; // 16-bit = 2 bytes per sample
  final fileSize = 36 + dataSize;

  final buffer = ByteData(44 + dataSize);

  // RIFF header
  buffer.setUint8(0, 0x52); // 'R'
  buffer.setUint8(1, 0x49); // 'I'
  buffer.setUint8(2, 0x46); // 'F'
  buffer.setUint8(3, 0x46); // 'F'
  buffer.setUint32(4, fileSize, Endian.little); // File size - 8
  buffer.setUint8(8, 0x57);  // 'W'
  buffer.setUint8(9, 0x41);  // 'A'
  buffer.setUint8(10, 0x56); // 'V'
  buffer.setUint8(11, 0x45); // 'E'

  // fmt chunk
  buffer.setUint8(12, 0x66); // 'f'
  buffer.setUint8(13, 0x6D); // 'm'
  buffer.setUint8(14, 0x74); // 't'
  buffer.setUint8(15, 0x20); // ' '
  buffer.setUint32(16, 16, Endian.little); // fmt chunk size
  buffer.setUint16(20, 1, Endian.little); // Audio format (1 = PCM)
  buffer.setUint16(22, 1, Endian.little); // Number of channels (1 = mono)
  buffer.setUint32(24, sampleRate, Endian.little); // Sample rate
  buffer.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
  buffer.setUint16(32, 2, Endian.little); // Block align
  buffer.setUint16(34, 16, Endian.little); // Bits per sample

  // data chunk
  buffer.setUint8(36, 0x64); // 'd'
  buffer.setUint8(37, 0x61); // 'a'
  buffer.setUint8(38, 0x74); // 't'
  buffer.setUint8(39, 0x61); // 'a'
  buffer.setUint32(40, dataSize, Endian.little); // Data size

  // Write audio samples
  for (int i = 0; i < samples.length; i++) {
    buffer.setInt16(44 + i * 2, samples[i], Endian.little);
  }

  await file.writeAsBytes(buffer.buffer.asUint8List());
}

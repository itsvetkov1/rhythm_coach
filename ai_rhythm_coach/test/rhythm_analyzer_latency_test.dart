import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rhythm_coach/services/rhythm_analyzer.dart';
import 'package:ai_rhythm_coach/models/tap_event.dart';

void main() {
  group('RhythmAnalyzer Latency Tests', () {
    late RhythmAnalyzer analyzer;
    late String tempFilePath;

    setUp(() {
      analyzer = RhythmAnalyzer();
      tempFilePath = '${Directory.systemTemp.path}/test_audio.wav';
    });

    tearDown(() {
      final file = File(tempFilePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    // Helper to generate WAV file with clicks
    Future<void> generateTestWav({
      required double durationSeconds,
      required List<double> clickTimes,
      int sampleRate = 44100,
    }) async {
      final numSamples = (durationSeconds * sampleRate).round();
      final samples = Float64List(numSamples);

      // Silence
      for (int i = 0; i < numSamples; i++) {
        samples[i] = 0.0;
      }

      // Add clicks (sine burst)
      for (final time in clickTimes) {
        final startSample = (time * sampleRate).round();
        if (startSample < numSamples) {
          for (int i = 0; i < 1000; i++) { // 1000 samples burst (~22ms)
            if (startSample + i < numSamples) {
              samples[startSample + i] = sin(2 * pi * 440 * i / sampleRate);
            }
          }
        }
      }

      // Write WAV
      final file = File(tempFilePath);
      final builder = BytesBuilder();

      // RIFF header
      builder.add('RIFF'.codeUnits);
      builder.addByte(0); builder.addByte(0); builder.addByte(0); builder.addByte(0); // Size placeholder
      builder.add('WAVE'.codeUnits);

      // fmt chunk
      builder.add('fmt '.codeUnits);
      builder.add([16, 0, 0, 0]); // Chunk size 16
      builder.add([1, 0]); // PCM
      builder.add([1, 0]); // Channels 1
      builder.add([68, 172, 0, 0]); // Sample rate 44100 (0xAC44)
      builder.add([136, 88, 1, 0]); // Byte rate (44100 * 2)
      builder.add([2, 0]); // Block align 2
      builder.add([16, 0]); // Bits per sample 16

      // data chunk
      builder.add('data'.codeUnits);
      final dataSize = numSamples * 2;
      builder.add([
        dataSize & 0xFF,
        (dataSize >> 8) & 0xFF,
        (dataSize >> 16) & 0xFF,
        (dataSize >> 24) & 0xFF
      ]);

      for (int i = 0; i < numSamples; i++) {
        final val = (samples[i] * 32767).round().clamp(-32768, 32767);
        builder.addByte(val & 0xFF);
        builder.addByte((val >> 8) & 0xFF);
      }

      final bytes = builder.toBytes();
      // Fix file size in RIFF header
      final totalSize = bytes.length - 8;
      bytes[4] = totalSize & 0xFF;
      bytes[5] = (totalSize >> 8) & 0xFF;
      bytes[6] = (totalSize >> 16) & 0xFF;
      bytes[7] = (totalSize >> 24) & 0xFF;

      await file.writeAsBytes(bytes);
    }

    test('analyzeAudio applies latency compensation correctly', () async {
      // Generate audio with clicks exactly at 1.0s, 2.0s, 3.0s (60 BPM)
      // This matches expected beats for 60 BPM starting at 0.0, 1.0, 2.0...
      await generateTestWav(
        durationSeconds: 4.0,
        clickTimes: [1.0, 2.0, 3.0],
      );

      // 1. Analyze with 0 latency offset
      // Expect near-zero error (clicks are perfectly on beat)
      final events0 = await analyzer.analyzeAudio(
        audioFilePath: tempFilePath,
        bpm: 60,
        durationSeconds: 4,
        latencyOffsetMs: 0,
        checkBleed: false,
      );

      expect(events0, isNotEmpty);
      final meanError0 = RhythmAnalyzer.calculateMeanSignedError(events0);
      print('Mean error (0 latency): $meanError0 ms');
      expect(meanError0.abs(), lessThan(50)); // Should be close to 0

      // 2. Analyze with 100ms latency offset
      // This means we are telling the analyzer: "The system recorded these clicks 100ms LATE."
      // So the analyzer should subtract 100ms from the detected times.
      // Detected times were ~1.0, ~2.0.
      // Corrected times will be ~0.9, ~1.9.
      // Expected times are 1.0, 2.0.
      // Error = Corrected - Expected = (1.0 - 0.1) - 1.0 = -0.1s = -100ms.
      // So MeanSignedError should be approx -100ms.
      
      final events100 = await analyzer.analyzeAudio(
        audioFilePath: tempFilePath,
        bpm: 60,
        durationSeconds: 4,
        latencyOffsetMs: 100,
        checkBleed: false,
      );

      expect(events100, isNotEmpty);
      final meanError100 = RhythmAnalyzer.calculateMeanSignedError(events100);
      print('Mean error (100 latency): $meanError100 ms');
      
      // We expect the error to shift by roughly -100ms relative to the baseline error
      // Use delta comparison to report the shift mostly
      expect(meanError100, closeTo(meanError0 - 100, 10)); // Allow 10ms tolerance
    });
    
    test('positive latency offset corrects for late recording', () async {
      // Simulate "Late" Recording
      // Generate audio with clicks at 1.1s, 2.1s... (100ms late vs 60 BPM grid)
      await generateTestWav(
        durationSeconds: 4.0,
        clickTimes: [1.1, 2.1, 3.1],
      );
      
      // Analyze with 0 offset -> Should show +100ms error
      final eventsLate = await analyzer.analyzeAudio(
        audioFilePath: tempFilePath,
        bpm: 60,
        durationSeconds: 4,
        latencyOffsetMs: 0,
        checkBleed: false,
      );
      
      final errorLate = RhythmAnalyzer.calculateMeanSignedError(eventsLate);
      print('Error (Late recording, 0 correction): $errorLate ms');
      expect(errorLate, closeTo(100, 20));
      
      // Analyze with 100ms offset -> Should show ~0ms error (Corrected!)
      final eventsCorrected = await analyzer.analyzeAudio(
        audioFilePath: tempFilePath,
        bpm: 60,
        durationSeconds: 4,
        latencyOffsetMs: 100,
        checkBleed: false,
      );
      
      final errorCorrected = RhythmAnalyzer.calculateMeanSignedError(eventsCorrected);
      print('Error (Late recording, 100 correction): $errorCorrected ms');
      expect(errorCorrected, closeTo(0, 20));
    });
  });
}

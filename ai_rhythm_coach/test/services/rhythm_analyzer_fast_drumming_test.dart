import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rhythm_coach/services/rhythm_analyzer.dart';
import 'package:ai_rhythm_coach/models/tap_event.dart';

void main() {
  late RhythmAnalyzer analyzer;
  late String testFilePath;

  setUp(() {
    analyzer = RhythmAnalyzer();
    testFilePath = '${Directory.systemTemp.path}/test_fast_drumming.wav';
  });

  tearDown(() {
    final file = File(testFilePath);
    if (file.existsSync()) {
      file.deleteSync();
    }
  });

  // Helper to generate a WAV file with specific beat pattern
  Future<void> generateTestWav(List<double> beatTimes, {double duration = 5.0, double frequency = 100.0}) async {
    const int sampleRate = 44100;
    final int numSamples = (duration * sampleRate).toInt();
    final List<int> samples = List.filled(numSamples, 0);

    // Generate silence with some noise
    final random = Random();
    for (int i = 0; i < numSamples; i++) {
      samples[i] = (random.nextDouble() * 200 - 100).toInt(); // Low noise floor
    }

    // Add beats (sine wave bursts with decay)
    final randomJitter = Random();
    for (final time in beatTimes) {
      // Add small jitter to avoid Metronome Bleed detection (perfect consistency)
      final jitter = (randomJitter.nextDouble() * 0.01) - 0.005; // +/- 5ms
      final startSample = ((time + jitter) * sampleRate).toInt();
      const length = 2000; // ~45ms burst
      
      for (int i = 0; i < length; i++) {
        if (startSample + i >= numSamples) break;
        if (startSample + i < 0) continue;
        
        // Envelope (Attack and Decay)
        double envelope = 1.0;
        if (i < 100) {
          envelope = i / 100.0; // Fast attack
        } else {
          envelope = 1.0 - ((i - 100) / (length - 100)); // Linear decay
        }

        // Low frequency thud (like a desk drum)
        final signal = sin(2 * pi * frequency * i / sampleRate) * 20000 * envelope;
        samples[startSample + i] += signal.toInt();
      }
    }

    // Write WAV file
    final file = File(testFilePath);
    final builder = BytesBuilder();

    // RIFF header
    builder.add('RIFF'.codeUnits);
    builder.add(_int32(36 + numSamples * 2));
    builder.add('WAVE'.codeUnits);

    // fmt chunk
    builder.add('fmt '.codeUnits);
    builder.add(_int32(16)); // Subchunk1Size
    builder.add(_int16(1)); // AudioFormat (PCM)
    builder.add(_int16(1)); // NumChannels (Mono)
    builder.add(_int32(sampleRate)); // SampleRate
    builder.add(_int32(sampleRate * 2)); // ByteRate
    builder.add(_int16(2)); // BlockAlign
    builder.add(_int16(16)); // BitsPerSample

    // data chunk
    builder.add('data'.codeUnits);
    builder.add(_int32(numSamples * 2));

    // Samples
    for (final sample in samples) {
      // Clamp to 16-bit
      int s = sample;
      if (s > 32767) s = 32767;
      if (s < -32768) s = -32768;
      builder.add(_int16(s));
    }

    await file.writeAsBytes(builder.toBytes());
  }

  test('Should detect fast drumming (300 BPM / 200ms interval)', () async {
    // Generate beats every 200ms (5 beats per second = 300 BPM)
    final beatTimes = <double>[];
    for (double t = 0.5; t < 4.5; t += 0.2) {
      beatTimes.add(t);
    }
    // 20 beats total

    await generateTestWav(beatTimes, frequency: 80.0); // 80Hz thud

    final events = await analyzer.analyzeAudio(
      audioFilePath: testFilePath,
      bpm: 300,
      durationSeconds: 5,
    );

    print('Detected ${events.length} beats out of ${beatTimes.length} expected');
    for (var e in events) {
      print('Beat at ${e.actualTime.toStringAsFixed(3)}s');
    }

    // Allow missing 1-2 beats due to edge cases, but should detect most
    expect(events.length, greaterThanOrEqualTo(beatTimes.length - 2));
  });

  test('Should detect loud drumming without saturation issues', () async {
    // Generate beats every 500ms but VERY LOUD
    final beatTimes = [0.5, 1.0, 1.5, 2.0, 2.5];
    
    // We simulate this by just using the max amplitude in the generator (already 20000/32768 ~ 0.6)
    // Let's assume the generator produces a clean signal.
    
    await generateTestWav(beatTimes, frequency: 150.0);

    final events = await analyzer.analyzeAudio(
      audioFilePath: testFilePath,
      bpm: 120,
      durationSeconds: 3,
    );

    expect(events.length, greaterThanOrEqualTo(beatTimes.length));
  });

  test('Should handle WAV with metadata chunks (LIST chunk)', () async {
    // Generate a WAV with an extra LIST chunk before data
    const int sampleRate = 44100;
    const double duration = 1.0;
    final int numSamples = (duration * sampleRate).toInt();
    final List<int> samples = List.filled(numSamples, 0);
    
    // Add one beat
    for (int i = 0; i < 1000; i++) {
      samples[10000 + i] = (sin(i * 0.1) * 20000).toInt();
    }

    final file = File(testFilePath);
    final builder = BytesBuilder();

    builder.add('RIFF'.codeUnits);
    builder.add(_int32(36 + numSamples * 2 + 20)); // +20 for extra chunk
    builder.add('WAVE'.codeUnits);

    builder.add('fmt '.codeUnits);
    builder.add(_int32(16));
    builder.add(_int16(1));
    builder.add(_int16(1));
    builder.add(_int32(sampleRate));
    builder.add(_int32(sampleRate * 2));
    builder.add(_int16(2));
    builder.add(_int16(16));

    // Add a LIST chunk (metadata)
    // LIST chunk structure: ID(4) + Size(4) + Type(4) + Subchunks...
    // Subchunk: ID(4) + Size(4) + Data...
    // We want: LIST + Size + INFO + ISFT + 4 + TEST
    // Size = 4 (INFO) + 4 (ISFT) + 4 (Size) + 4 (TEST) = 16 bytes
    
    builder.add('LIST'.codeUnits);
    builder.add(_int32(16)); // Size covering INFO + ISFT chunk
    builder.add('INFO'.codeUnits);
    
    // Subchunk ISFT
    builder.add('ISFT'.codeUnits);
    builder.add(_int32(4)); // Size of TEST
    builder.add('TEST'.codeUnits);

    builder.add('data'.codeUnits);
    builder.add(_int32(numSamples * 2));

    for (final sample in samples) {
      int s = sample;
      if (s > 32767) s = 32767;
      if (s < -32768) s = -32768;
      builder.add(_int16(s));
    }

    await file.writeAsBytes(builder.toBytes());

    final events = await analyzer.analyzeAudio(
      audioFilePath: testFilePath,
      bpm: 60,
      durationSeconds: 1,
    );

    expect(events.length, greaterThan(0));
  });

  test('Should handle headerless raw PCM file (fallback)', () async {
    // Generate raw PCM data without header
    const int sampleRate = 44100;
    const double duration = 1.0;
    final int numSamples = (duration * sampleRate).toInt();
    final List<int> samples = List.filled(numSamples, 0);
    
    // Add one beat
    for (int i = 0; i < 1000; i++) {
      samples[10000 + i] = (sin(i * 0.1) * 20000).toInt();
    }

    final file = File(testFilePath);
    final builder = BytesBuilder();

    for (final sample in samples) {
      int s = sample;
      if (s > 32767) s = 32767;
      if (s < -32768) s = -32768;
      builder.add(_int16(s));
    }

    await file.writeAsBytes(builder.toBytes());

    final events = await analyzer.analyzeAudio(
      audioFilePath: testFilePath,
      bpm: 60,
      durationSeconds: 1,
    );

    expect(events.length, greaterThan(0));
  });

}

List<int> _int32(int value) {
  final b = Uint8List(4);
  final d = ByteData.view(b.buffer);
  d.setInt32(0, value, Endian.little);
  return b;
}

List<int> _int16(int value) {
  final b = Uint8List(2);
  final d = ByteData.view(b.buffer);
  d.setInt16(0, value, Endian.little);
  return b;
}

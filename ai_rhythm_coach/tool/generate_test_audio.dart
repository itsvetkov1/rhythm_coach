import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Generate synthetic audio test files for onset detection testing.
/// Creates WAV files with proper headers in 44.1kHz, mono, PCM 16-bit format.
void main() async {
  print('Generating test audio files...');

  final outputDir = Directory('test/fixtures/audio');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  // Generate test files
  await generateSilence(outputDir);
  await generateWhiteNoise(outputDir);
  await generateDrumHits(outputDir);

  print('All test audio files generated successfully!');
}

/// Generate test_silence.wav: 5 seconds of digital silence
Future<void> generateSilence(Directory outputDir) async {
  print('Generating test_silence.wav...');

  const sampleRate = 44100;
  const durationSeconds = 5;
  const numSamples = sampleRate * durationSeconds;

  final samples = Int16List(numSamples); // All zeros = silence

  final file = File('${outputDir.path}/test_silence.wav');
  await writeWavFile(file, samples, sampleRate);

  print('  Created: ${file.path} (${numSamples} samples)');
}

/// Generate test_white_noise.wav: 5 seconds of low-level white noise (RMS ~0.05)
Future<void> generateWhiteNoise(Directory outputDir) async {
  print('Generating test_white_noise.wav...');

  const sampleRate = 44100;
  const durationSeconds = 5;
  const numSamples = sampleRate * durationSeconds;
  const targetRms = 0.05; // Low-level noise

  final random = Random(42); // Seed for reproducibility
  final samples = Int16List(numSamples);

  // Generate white noise with target RMS
  for (int i = 0; i < numSamples; i++) {
    // Random value between -1.0 and 1.0
    final normalized = (random.nextDouble() * 2.0) - 1.0;
    // Scale to target RMS and convert to int16
    final scaled = normalized * targetRms;
    samples[i] = (scaled * 32767).round().clamp(-32768, 32767);
  }

  final file = File('${outputDir.path}/test_white_noise.wav');
  await writeWavFile(file, samples, sampleRate);

  print('  Created: ${file.path} (${numSamples} samples, RMS ~$targetRms)');
}

/// Generate test_drum_hits.wav: 8 clean impulse sounds at 120 BPM
Future<void> generateDrumHits(Directory outputDir) async {
  print('Generating test_drum_hits.wav...');

  const sampleRate = 44100;
  const bpm = 120;
  const numHits = 8;
  final beatDurationSamples = (sampleRate * 60 / bpm).round(); // Samples per beat

  // Calculate total duration (with some padding)
  final totalDurationSamples = beatDurationSamples * (numHits + 1);
  final samples = Int16List(totalDurationSamples);

  // Generate impulse hits at each beat
  for (int hit = 0; hit < numHits; hit++) {
    final hitPosition = beatDurationSamples * (hit + 1); // Start after one beat
    _generateImpulse(samples, hitPosition, sampleRate);
  }

  final file = File('${outputDir.path}/test_drum_hits.wav');
  await writeWavFile(file, samples, sampleRate);

  print('  Created: ${file.path} ($numHits hits at $bpm BPM)');
}

/// Generate a realistic drum hit impulse at the given position
void _generateImpulse(Int16List samples, int position, int sampleRate) {
  // Drum hit characteristics:
  // - Sharp attack (few samples)
  // - Exponential decay (~100ms)
  // - High amplitude

  const attackSamples = 5; // Very fast attack
  const decayTimeMs = 100;
  final decaySamples = (sampleRate * decayTimeMs / 1000).round();

  // Peak amplitude (about 70% of maximum to avoid clipping)
  const peakAmplitude = 0.7;

  for (int i = 0; i < decaySamples && (position + i) < samples.length; i++) {
    double envelope;

    if (i < attackSamples) {
      // Linear attack
      envelope = i / attackSamples;
    } else {
      // Exponential decay
      final t = (i - attackSamples) / decaySamples;
      envelope = exp(-5 * t); // Exponential decay factor
    }

    // Add some frequency content (mixture of frequencies for realism)
    final t = i / sampleRate;
    final signal = sin(2 * pi * 200 * t) * 0.5 +  // Low frequency
                   sin(2 * pi * 800 * t) * 0.3 +  // Mid frequency
                   sin(2 * pi * 2000 * t) * 0.2;  // High frequency

    final amplitude = signal * envelope * peakAmplitude;
    final sample = (amplitude * 32767).round().clamp(-32768, 32767);

    samples[position + i] = sample;
  }
}

/// Write PCM samples to a WAV file with proper header
Future<void> writeWavFile(File file, Int16List samples, int sampleRate) async {
  const numChannels = 1; // Mono
  const bitsPerSample = 16;
  final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
  final blockAlign = numChannels * bitsPerSample ~/ 8;

  final dataSize = samples.length * 2; // 2 bytes per sample (16-bit)
  final fileSize = 36 + dataSize;

  final buffer = BytesBuilder();

  // RIFF header
  buffer.add('RIFF'.codeUnits);
  buffer.add(_int32ToBytes(fileSize));
  buffer.add('WAVE'.codeUnits);

  // fmt subchunk
  buffer.add('fmt '.codeUnits);
  buffer.add(_int32ToBytes(16)); // Subchunk size
  buffer.add(_int16ToBytes(1)); // Audio format (1 = PCM)
  buffer.add(_int16ToBytes(numChannels));
  buffer.add(_int32ToBytes(sampleRate));
  buffer.add(_int32ToBytes(byteRate));
  buffer.add(_int16ToBytes(blockAlign));
  buffer.add(_int16ToBytes(bitsPerSample));

  // data subchunk
  buffer.add('data'.codeUnits);
  buffer.add(_int32ToBytes(dataSize));

  // PCM data (little-endian)
  for (final sample in samples) {
    buffer.add(_int16ToBytes(sample));
  }

  await file.writeAsBytes(buffer.toBytes());
}

/// Convert int32 to little-endian bytes
List<int> _int32ToBytes(int value) {
  return [
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ];
}

/// Convert int16 to little-endian bytes
List<int> _int16ToBytes(int value) {
  return [
    value & 0xFF,
    (value >> 8) & 0xFF,
  ];
}

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() async {
  print('Generating metronome click sounds...');

  // Generate high click (800 Hz)
  await generateWavFile(
    frequency: 800,
    durationMs: 50,
    outputPath: 'assets/audio/click_high.wav',
  );
  print('✓ Generated click_high.wav');

  // Generate low click (400 Hz)
  await generateWavFile(
    frequency: 400,
    durationMs: 50,
    outputPath: 'assets/audio/click_low.wav',
  );
  print('✓ Generated click_low.wav');

  print('\nMetronome sounds generated successfully!');
}

Future<void> generateWavFile({
  required int frequency,
  required int durationMs,
  required String outputPath,
}) async {
  const int sampleRate = 44100;
  const int bitsPerSample = 16;
  const int numChannels = 1; // Mono

  // Calculate number of samples
  final int numSamples = (sampleRate * durationMs / 1000).round();

  // Generate sine wave samples
  final samples = <int>[];
  for (int i = 0; i < numSamples; i++) {
    // Calculate sine wave value
    final double time = i / sampleRate;
    double value = sin(2 * pi * frequency * time);

    // Apply envelope (fade in/out) to avoid clicks
    final double envelope = _applyEnvelope(i, numSamples);
    value *= envelope;

    // Convert to 16-bit integer
    final int sample = (value * 32767).round().clamp(-32768, 32767);
    samples.add(sample);
  }

  // Create WAV file
  final wavBytes = _createWavBytes(samples, sampleRate, bitsPerSample, numChannels);

  // Ensure directory exists
  final file = File(outputPath);
  await file.parent.create(recursive: true);

  // Write to file
  await file.writeAsBytes(wavBytes);
}

double _applyEnvelope(int sampleIndex, int totalSamples) {
  const int fadeLength = 100; // samples for fade in/out

  if (sampleIndex < fadeLength) {
    // Fade in
    return sampleIndex / fadeLength;
  } else if (sampleIndex > totalSamples - fadeLength) {
    // Fade out
    return (totalSamples - sampleIndex) / fadeLength;
  } else {
    // Full volume
    return 1.0;
  }
}

Uint8List _createWavBytes(
  List<int> samples,
  int sampleRate,
  int bitsPerSample,
  int numChannels,
) {
  final int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
  final int blockAlign = numChannels * bitsPerSample ~/ 8;
  final int dataSize = samples.length * bitsPerSample ~/ 8;
  final int fileSize = 36 + dataSize;

  final buffer = BytesBuilder();

  // RIFF header
  buffer.add('RIFF'.codeUnits);
  buffer.add(_int32ToBytes(fileSize));
  buffer.add('WAVE'.codeUnits);

  // Format chunk
  buffer.add('fmt '.codeUnits);
  buffer.add(_int32ToBytes(16)); // Chunk size
  buffer.add(_int16ToBytes(1)); // Audio format (1 = PCM)
  buffer.add(_int16ToBytes(numChannels));
  buffer.add(_int32ToBytes(sampleRate));
  buffer.add(_int32ToBytes(byteRate));
  buffer.add(_int16ToBytes(blockAlign));
  buffer.add(_int16ToBytes(bitsPerSample));

  // Data chunk
  buffer.add('data'.codeUnits);
  buffer.add(_int32ToBytes(dataSize));

  // Sample data
  for (final sample in samples) {
    buffer.add(_int16ToBytes(sample));
  }

  return buffer.toBytes();
}

Uint8List _int16ToBytes(int value) {
  final bytes = Uint8List(2);
  bytes[0] = value & 0xFF;
  bytes[1] = (value >> 8) & 0xFF;
  return bytes;
}

Uint8List _int32ToBytes(int value) {
  final bytes = Uint8List(4);
  bytes[0] = value & 0xFF;
  bytes[1] = (value >> 8) & 0xFF;
  bytes[2] = (value >> 16) & 0xFF;
  bytes[3] = (value >> 24) & 0xFF;
  return bytes;
}

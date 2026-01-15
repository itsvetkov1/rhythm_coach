import 'dart:io';
import 'dart:typed_data';

/// Utility class for loading test audio fixtures
class AudioFixtureLoader {
  /// Load a test audio fixture by filename
  ///
  /// [filename] - Name of the fixture file (e.g., 'test_silence.wav')
  ///
  /// Returns the PCM samples as Float64List normalized to -1.0 to 1.0 range
  ///
  /// Throws FileSystemException if the file doesn't exist
  static Future<Float64List> loadTestAudioFixture(String filename) async {
    final fixturePath = 'test/fixtures/audio/$filename';
    final file = File(fixturePath);

    if (!file.existsSync()) {
      throw FileSystemException(
        'Test audio fixture not found: $fixturePath',
        fixturePath,
      );
    }

    final bytes = await file.readAsBytes();
    return _parseWavFile(bytes);
  }

  /// Parse a WAV file and extract PCM samples
  ///
  /// Currently supports: 44.1kHz, mono, 16-bit PCM
  static Float64List _parseWavFile(Uint8List bytes) {
    // Verify RIFF header
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    if (riff != 'RIFF') {
      throw FormatException('Invalid WAV file: Missing RIFF header');
    }

    // Verify WAVE format
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (wave != 'WAVE') {
      throw FormatException('Invalid WAV file: Missing WAVE format');
    }

    // Find data chunk
    int dataOffset = 12;
    int dataSize = 0;

    while (dataOffset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(dataOffset, dataOffset + 4));
      final chunkSize = _readInt32(bytes, dataOffset + 4);

      if (chunkId == 'data') {
        dataSize = chunkSize;
        dataOffset += 8; // Move to start of actual data
        break;
      }

      // Move to next chunk
      dataOffset += 8 + chunkSize;
    }

    if (dataSize == 0) {
      throw FormatException('Invalid WAV file: No data chunk found');
    }

    // Extract 16-bit PCM samples
    final numSamples = dataSize ~/ 2; // 2 bytes per sample
    final samples = Float64List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final offset = dataOffset + (i * 2);
      final int16Value = _readInt16(bytes, offset);
      // Normalize to -1.0 to 1.0 range
      samples[i] = int16Value / 32768.0;
    }

    return samples;
  }

  /// Read a 32-bit little-endian integer from bytes
  static int _readInt32(Uint8List bytes, int offset) {
    return bytes[offset] |
           (bytes[offset + 1] << 8) |
           (bytes[offset + 2] << 16) |
           (bytes[offset + 3] << 24);
  }

  /// Read a 16-bit little-endian signed integer from bytes
  static int _readInt16(Uint8List bytes, int offset) {
    final value = bytes[offset] | (bytes[offset + 1] << 8);
    // Convert to signed
    return value > 32767 ? value - 65536 : value;
  }
}

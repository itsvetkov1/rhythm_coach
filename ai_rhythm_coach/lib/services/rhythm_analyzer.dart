import 'dart:io';
import 'dart:math';
import 'package:fftea/fftea.dart';
import '../models/tap_event.dart';

class MetronomeBleedException implements Exception {
  final String message;
  MetronomeBleedException(this.message);
  @override
  String toString() => message;
}

class RhythmAnalyzer {
  static const int fftSize = 2048;
  static const int hopSize = 512;
  static const double sampleRate = 44100;
  static const double onsetThreshold = 0.12; // Threshold for normalized spectral flux (lowered for maximum sensitivity)
  static const double minSignalEnergy = 0.00003; // Minimum RMS energy (extremely sensitive to detect even soft claps)
  static const double noiseFloor = 0.00001; // Ignore samples below this threshold

  // Analyze audio file for rhythm accuracy
  Future<List<TapEvent>> analyzeAudio({
    required String audioFilePath,
    required int bpm,
    required int durationSeconds,
  }) async {
    try {
      // Load audio samples
      final samples = await _loadAudioSamples(audioFilePath);

      if (samples.isEmpty) {
        return [];
      }

      // Check if recording has sufficient signal energy
      final rmsEnergy = _calculateRMS(samples);
      final maxAmplitude = samples.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
      final duration = samples.length / sampleRate;

      print('DEBUG: ========== Audio Analysis Debug Info ==========');
      print('DEBUG: Total samples loaded: ${samples.length}');
      print('DEBUG: Duration: ${duration.toStringAsFixed(2)}s');
      print('DEBUG: Recording RMS energy: ${rmsEnergy.toStringAsFixed(6)}');
      print('DEBUG: Max amplitude: ${maxAmplitude.toStringAsFixed(6)}');
      print('DEBUG: Minimum required energy: ${minSignalEnergy.toStringAsFixed(6)}');
      print('DEBUG: Energy check: ${rmsEnergy >= minSignalEnergy ? "PASS" : "FAIL"}');

      if (rmsEnergy < minSignalEnergy) {
        // Recording is too quiet or silent - no valid performance detected
        print('WARNING: Recording energy too low (RMS: ${rmsEnergy.toStringAsFixed(6)}). '
            'Please tap louder or check microphone.');
        print('DEBUG: ================================================');
        return [];
      }

      // Detect onset times (in seconds)
      final onsetTimes = _detectOnsets(samples);
      print('DEBUG: Detected ${onsetTimes.length} onsets');
      if (onsetTimes.isNotEmpty) {
        print('DEBUG: First few onset times: ${onsetTimes.take(10).map((t) => t.toStringAsFixed(3)).toList()}');
      }

      // Generate expected beat times
      final expectedBeats = _generateExpectedBeats(bpm, durationSeconds);
      print('DEBUG: Expected ${expectedBeats.length} beats for ${durationSeconds}s at $bpm BPM');

      // Match onsets to nearest expected beats
      final tapEvents = _matchOnsetsToBeats(onsetTimes, expectedBeats);
      print('DEBUG: Matched ${tapEvents.length} beats (${((tapEvents.length / expectedBeats.length) * 100).toStringAsFixed(1)}% of expected)');
      print('DEBUG: ================================================');

      // Check for metronome bleed (extremely high consistency)
      // Machine-generated audio loopback (bleed) has near-zero variance (< 1ms).
      // Human playing, even professional, rarely achieves < 5-10ms consistency over 60s.
      if (tapEvents.isNotEmpty) {
        final consistency = calculateConsistency(tapEvents);
        if (consistency < 3.0) {
          // It's likely the microphone hearing the metronome speaker
          throw MetronomeBleedException(
              'Metronome bleed detected (Consistency: ${consistency.toStringAsFixed(2)}ms). Please use headphones to prevent the microphone from picking up the metronome.');
        }
      }

      return tapEvents;
    } catch (e, stackTrace) {
      // Log error and return empty list if analysis fails
      print('ERROR: Rhythm analysis failed: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Calculate RMS (Root Mean Square) energy of the signal
  double _calculateRMS(List<double> samples) {
    if (samples.isEmpty) return 0.0;

    double sumSquares = 0.0;
    for (final sample in samples) {
      sumSquares += sample * sample;
    }

    return sqrt(sumSquares / samples.length);
  }

  // Load audio file and convert to samples
  // Properly parses WAV file structure to find the audio data chunk
  Future<List<double>> _loadAudioSamples(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('DEBUG: Audio file does not exist: $filePath');
        return [];
      }

      // Read file bytes
      final bytes = await file.readAsBytes();
      print('DEBUG: Audio file size: ${bytes.length} bytes');

      if (bytes.length < 44) {
        print('DEBUG: File too small to be valid WAV (< 44 bytes)');
        return [];
      }

      // Verify RIFF header
      final riffHeader = String.fromCharCodes(bytes.sublist(0, 4));
      if (riffHeader != 'RIFF') {
        print('DEBUG: Not a valid WAV file (missing RIFF header)');
        return [];
      }

      // Verify WAVE format
      final waveFormat = String.fromCharCodes(bytes.sublist(8, 12));
      if (waveFormat != 'WAVE') {
        print('DEBUG: Not a valid WAV file (missing WAVE format)');
        return [];
      }

      // Find the 'data' chunk by searching through the file
      // WAV files can have multiple chunks (fmt, fact, LIST, INFO, data, etc.)
      int dataOffset = -1;
      int dataSize = 0;
      int offset = 12; // Start after RIFF header

      while (offset < bytes.length - 8) {
        final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        final chunkSize = bytes[offset + 4] |
                         (bytes[offset + 5] << 8) |
                         (bytes[offset + 6] << 16) |
                         (bytes[offset + 7] << 24);

        print('DEBUG: Found chunk "$chunkId" at offset $offset, size $chunkSize bytes');

        if (chunkId == 'data') {
          dataOffset = offset + 8; // Skip chunk header
          dataSize = chunkSize;
          break;
        }

        // Move to next chunk
        offset += 8 + chunkSize;

        // WAV chunks are word-aligned (even-byte boundary)
        if (chunkSize % 2 == 1) {
          offset += 1;
        }
      }

      if (dataOffset == -1) {
        print('DEBUG: Could not find data chunk in WAV file. Attempting fallback parsing.');
        // Fallback: Assume standard header size of 44 bytes if parsing fails
        // This handles cases where the WAV header might be non-standard or the parser fails
        dataOffset = 44;
        dataSize = bytes.length - 44;
      }

      print('DEBUG: Data chunk found at offset $dataOffset, size $dataSize bytes');

      // Convert bytes to amplitude values (16-bit PCM)
      final samples = <double>[];
      final endOffset = min(dataOffset + dataSize, bytes.length);

      for (int i = dataOffset; i < endOffset - 1; i += 2) {
        // Read 16-bit little-endian samples
        final sample = (bytes[i] | (bytes[i + 1] << 8));
        final signed = sample > 32767 ? sample - 65536 : sample;
        final normalized = signed / 32768.0;
        samples.add(normalized);
      }

      print('DEBUG: Parsed ${samples.length} audio samples from WAV file');

      return samples;
    } catch (e) {
      print('DEBUG: Error loading audio samples: $e');
      return [];
    }
  }

  // Detect onset times using FFT spectral flux
  List<double> _detectOnsets(List<double> samples) {
    final onsets = <double>[];

    if (samples.length < fftSize) {
      return onsets;
    }

    final fft = FFT(fftSize);
    List<double>? previousMagnitudes;

    // Sliding window FFT
    for (int i = 0; i < samples.length - fftSize; i += hopSize) {
      final window = samples.sublist(i, i + fftSize);

      // Apply Hanning window to reduce spectral leakage
      final windowedSamples = _applyHanningWindow(window);

      // Perform FFT
      final complexSpectrum = fft.realFft(windowedSamples);

      // Calculate magnitudes
      final magnitudes = <double>[];
      for (int j = 0; j < complexSpectrum.length; j++) {
        final real = complexSpectrum[j].x;
        final imag = complexSpectrum[j].y;
        magnitudes.add(sqrt(real * real + imag * imag));
      }

      // Calculate spectral flux (difference from previous frame)
      if (previousMagnitudes != null) {
        double flux = 0.0;
        double previousEnergy = 0.0;

        // Calculate flux and previous frame energy
        for (int j = 0; j < magnitudes.length; j++) {
          final diff = magnitudes[j] - previousMagnitudes[j];
          // Only consider increases (positive differences)
          if (diff > 0) {
            flux += diff;
          }
          previousEnergy += previousMagnitudes[j];
        }

        // Normalize flux by previous frame energy to handle varying volume levels
        // Add small epsilon to avoid division by zero
        final normalizedFlux = previousEnergy > 0
            ? flux / (previousEnergy + 0.0001)
            : 0.0;

        // If normalized flux exceeds threshold, mark as onset
        if (normalizedFlux > onsetThreshold) {
          final timeInSeconds = i / sampleRate;
          // Avoid marking onsets too close together (minimum 50ms apart)
          if (onsets.isEmpty || (timeInSeconds - onsets.last) > 0.05) {
            onsets.add(timeInSeconds);
          }
        }
      }

      previousMagnitudes = magnitudes;
    }

    return onsets;
  }

  // Apply Hanning window to reduce spectral leakage
  List<double> _applyHanningWindow(List<double> samples) {
    final windowed = <double>[];
    final n = samples.length;

    for (int i = 0; i < n; i++) {
      final window = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
      windowed.add(samples[i] * window);
    }

    return windowed;
  }

  // Generate expected beat times for given BPM
  List<double> _generateExpectedBeats(int bpm, int durationSeconds) {
    final beats = <double>[];
    final beatInterval = 60.0 / bpm; // Seconds per beat

    for (double time = 0; time < durationSeconds; time += beatInterval) {
      beats.add(time);
    }

    return beats;
  }

  // Match detected onsets to expected beats
  List<TapEvent> _matchOnsetsToBeats(
    List<double> onsetTimes,
    List<double> expectedBeats,
  ) {
    final tapEvents = <TapEvent>[];

    for (final expectedTime in expectedBeats) {
      // Find nearest onset within ±300ms window
      final nearestOnset = _findNearestOnset(
        onsetTimes,
        expectedTime,
        maxDistance: 0.3, // 300ms tolerance
      );

      if (nearestOnset != null) {
        final error = (nearestOnset - expectedTime) * 1000; // Convert to ms

        tapEvents.add(TapEvent(
          actualTime: nearestOnset,
          expectedTime: expectedTime,
          error: error,
        ));
      }
    }

    return tapEvents;
  }

  // Find nearest onset to target time
  double? _findNearestOnset(
    List<double> onsets,
    double targetTime, {
    required double maxDistance,
  }) {
    double? nearest;
    double minDistance = double.infinity;

    for (final onset in onsets) {
      final distance = (onset - targetTime).abs();
      if (distance < minDistance && distance <= maxDistance) {
        minDistance = distance;
        nearest = onset;
      }
    }

    return nearest;
  }

  // Calculate average error from tap events
  static double calculateAverageError(List<TapEvent> tapEvents) {
    if (tapEvents.isEmpty) return 0.0;

    final sum = tapEvents.fold<double>(0.0, (sum, event) => sum + event.error.abs());
    return sum / tapEvents.length;
  }

  // Calculate consistency (standard deviation of errors)
  static double calculateConsistency(List<TapEvent> tapEvents) {
    if (tapEvents.isEmpty) return 0.0;

    final errors = tapEvents.map((e) => e.error).toList();
    final mean = errors.reduce((a, b) => a + b) / errors.length;

    final variance = errors.fold<double>(
          0.0,
          (sum, error) => sum + pow(error - mean, 2),
        ) /
        errors.length;

    return sqrt(variance);
  }
}

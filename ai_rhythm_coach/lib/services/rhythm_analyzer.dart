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
  static const double minSignalEnergy = 0.00003; // Minimum RMS energy (extremely sensitive to detect even soft claps)
  static const double noiseFloor = 0.00001; // Ignore samples below this threshold
  static const double _gamma = 10.0; // Log compression strength

  // Analyze audio file for rhythm accuracy
  Future<List<TapEvent>> analyzeAudio({
    required String audioFilePath,
    required int bpm,
    required int durationSeconds,
    int latencyOffsetMs = 0,
    bool checkBleed = true,
  }) async {
    try {
      // Load audio samples
      final samples = await _loadAudioSamples(audioFilePath);

      if (samples.isEmpty) {
        return [];
      }

      // Check if recording has sufficient signal energy
      final rmsEnergy = _calculateRMS(samples);
      final duration = samples.length / sampleRate;

      print('Audio analysis: ${samples.length} samples, ${duration.toStringAsFixed(2)}s, RMS=${rmsEnergy.toStringAsFixed(6)}');

      if (rmsEnergy < minSignalEnergy) {
        print('WARNING: Recording energy too low (RMS: ${rmsEnergy.toStringAsFixed(6)}). '
            'Please tap louder or check microphone.');
        return [];
      }

      // Detect onset times (in seconds) using adaptive thresholding
      final rawOnsetTimes = _detectOnsets(samples, bpm);

      // Apply latency compensation
      final double latencySeconds = latencyOffsetMs / 1000.0;
      final onsetTimes = rawOnsetTimes.map((t) => t - latencySeconds).toList();

      // Generate expected beat times
      final expectedBeats = _generateExpectedBeats(bpm, durationSeconds);

      // Match onsets to nearest expected beats
      final tapEvents = _matchOnsetsToBeats(onsetTimes, expectedBeats);

      print('Onset detection: ${rawOnsetTimes.length} onsets, matched ${tapEvents.length}/${expectedBeats.length} beats (${((tapEvents.length / expectedBeats.length) * 100).toStringAsFixed(1)}%)');

      // Check for metronome bleed (extremely high consistency)
      // Machine-generated audio loopback (bleed) has near-zero variance (< 1ms).
      // Human playing, even professional, rarely achieves < 5-10ms consistency over 60s.
      if (checkBleed && tapEvents.isNotEmpty) {
        final consistency = calculateConsistency(tapEvents);
        if (consistency < 3.0) {
          throw MetronomeBleedException(
              'Metronome bleed detected (Consistency: ${consistency.toStringAsFixed(2)}ms). Please use headphones to prevent the microphone from picking up the metronome.');
        }
      }

      return tapEvents;
    } on MetronomeBleedException {
      rethrow;
    } on FileSystemException catch (e) {
      print('ERROR: File system error during analysis: $e');
      return [];
    } catch (e) {
      // Re-throw unexpected errors so they surface during development
      print('ERROR: Unexpected rhythm analysis failure: $e');
      rethrow;
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

  // Detect onset times using FFT spectral flux with adaptive thresholding.
  // Uses log-compressed magnitudes, adaptive threshold from local moving average,
  // local maximum peak picking, and BPM-aware minimum inter-onset interval.
  List<double> _detectOnsets(List<double> samples, int bpm) {
    final onsets = <double>[];

    if (samples.length < fftSize) {
      return onsets;
    }

    final fft = FFT(fftSize);
    final hanningWindow = Window.hanning(fftSize);
    List<double>? previousMagnitudes;

    // Pass 1: Compute all spectral flux values and frame times
    final fluxValues = <double>[];
    final frameTimes = <double>[];

    for (int i = 0; i <= samples.length - fftSize; i += hopSize) {
      final window = samples.sublist(i, i + fftSize);

      // Apply Hanning window using fftea's Window.hanning
      final windowedSamples = hanningWindow.applyWindowReal(window);

      // Perform FFT
      final complexSpectrum = fft.realFft(windowedSamples);

      // Extract magnitudes with logarithmic compression for volume invariance
      final magnitudes = <double>[];
      for (int j = 0; j < complexSpectrum.length; j++) {
        final real = complexSpectrum[j].x;
        final imag = complexSpectrum[j].y;
        final magnitude = sqrt(real * real + imag * imag);
        magnitudes.add(log(1.0 + _gamma * magnitude));
      }

      // Half-wave rectified spectral flux (only positive magnitude differences)
      if (previousMagnitudes != null) {
        double flux = 0.0;
        for (int j = 0; j < magnitudes.length; j++) {
          final diff = magnitudes[j] - previousMagnitudes![j];
          if (diff > 0) {
            flux += diff;
          }
        }
        fluxValues.add(flux);
        // Onset is between current and previous frame, use hop midpoint
        frameTimes.add((i + hopSize / 2) / sampleRate);
      }

      previousMagnitudes = magnitudes;
    }

    if (fluxValues.isEmpty) return onsets;

    // Pass 2: Apply adaptive thresholding and peak picking
    final thresholds = _adaptiveThreshold(fluxValues);
    final minInterval = _minOnsetInterval(bpm);

    for (int i = 1; i < fluxValues.length - 1; i++) {
      if (fluxValues[i] > thresholds[i] && _isLocalMax(fluxValues, i)) {
        final time = frameTimes[i];
        if (onsets.isEmpty || (time - onsets.last) > minInterval) {
          onsets.add(time);
        }
      }
    }

    return onsets;
  }

  // Compute adaptive threshold as a moving average of spectral flux values
  // multiplied by delta, plus a minimum floor offset.
  List<double> _adaptiveThreshold(List<double> fluxValues, {
    int preAvgFrames = 10,   // ~100ms lookback at 512 hop / 44100 Hz
    int postAvgFrames = 3,   // ~30ms lookahead
    double delta = 2.0,      // multiplier above local average
    double offset = 0.01,    // minimum threshold floor
  }) {
    final thresholds = <double>[];
    for (int i = 0; i < fluxValues.length; i++) {
      final start = max(0, i - preAvgFrames);
      final end = min(fluxValues.length, i + postAvgFrames + 1);
      final windowSlice = fluxValues.sublist(start, end);
      final avg = windowSlice.reduce((a, b) => a + b) / windowSlice.length;
      thresholds.add(avg * delta + offset);
    }
    return thresholds;
  }

  // BPM-aware minimum inter-onset interval to prevent double-triggers.
  // At 200 BPM (300ms beats), minimum is 120ms. At 40 BPM (1500ms beats), minimum is 600ms.
  double _minOnsetInterval(int bpm) {
    final beatInterval = 60.0 / bpm;
    return max(0.05, beatInterval * 0.4); // 40% of beat interval, min 50ms
  }

  // Check if flux[index] is a local maximum (greater than both neighbors)
  bool _isLocalMax(List<double> flux, int index) {
    if (index <= 0 || index >= flux.length - 1) return false;
    return flux[index] > flux[index - 1] && flux[index] > flux[index + 1];
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

  // Calculate mean signed error (useful for calibration)
  static double calculateMeanSignedError(List<TapEvent> tapEvents) {
    if (tapEvents.isEmpty) return 0.0;

    final sum = tapEvents.fold<double>(0.0, (sum, event) => sum + event.error);
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

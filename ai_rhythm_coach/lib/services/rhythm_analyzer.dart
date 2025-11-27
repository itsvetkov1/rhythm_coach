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
  static const double onsetThreshold = 0.1; // Will need tuning

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

      // Detect onset times (in seconds)
      final onsetTimes = _detectOnsets(samples);

      // Generate expected beat times
      final expectedBeats = _generateExpectedBeats(bpm, durationSeconds);

      // Match onsets to nearest expected beats
      final tapEvents = _matchOnsetsToBeats(onsetTimes, expectedBeats);

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
    } catch (e) {
      // Return empty list if analysis fails
      return [];
    }
  }

  // Load audio file and convert to samples
  // This is a simplified implementation that reads raw audio data
  // In production, you'd use a proper audio decoding library
  Future<List<double>> _loadAudioSamples(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return [];
      }

      // Read file bytes
      final bytes = await file.readAsBytes();

      // For AAC files, we'll skip the header and read the audio data
      // This is a simplified approach - proper decoding would use FFmpeg
      // For MVP, we'll use amplitude detection from raw bytes
      final samples = <double>[];

      // Convert bytes to amplitude values (simplified)
      // Skip first 1024 bytes (approximate header size)
      final startIndex = min(1024, bytes.length);

      for (int i = startIndex; i < bytes.length - 1; i += 2) {
        // Read 16-bit samples
        final sample = (bytes[i] | (bytes[i + 1] << 8));
        final signed = sample > 32767 ? sample - 65536 : sample;
        final normalized = signed / 32768.0;
        samples.add(normalized);
      }

      return samples;
    } catch (e) {
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
        for (int j = 0; j < magnitudes.length; j++) {
          final diff = magnitudes[j] - previousMagnitudes[j];
          // Only consider increases (positive differences)
          if (diff > 0) {
            flux += diff;
          }
        }

        // If flux exceeds threshold, mark as onset
        if (flux > onsetThreshold) {
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

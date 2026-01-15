import 'dart:io';
import 'dart:math';
import 'package:fftea/fftea.dart';
import 'package:path_provider/path_provider.dart';
import '../models/tap_event.dart';

class MetronomeBleedException implements Exception {
  final String message;
  MetronomeBleedException(this.message);
  @override
  String toString() => message;
}

/// Configuration parameters for onset detection algorithm tuning.
///
/// These parameters control the sensitivity and behavior of the onset detection
/// pipeline. Adjust these values to optimize detection accuracy and reduce
/// false positives for different recording environments.
class OnsetDetectionConfig {
  /// Absolute minimum threshold for spectral flux onset detection.
  /// The adaptive threshold will never go below this value, even in perfect silence.
  /// Higher values reduce false positives but may miss quiet hits.
  /// Typical range: 0.1 to 0.3
  /// Default: 0.15
  final double minimumThreshold;

  /// Multiplier applied to noise floor when calculating adaptive threshold.
  /// Formula: threshold = noiseFloor * noiseFloorMultiplier + 0.1
  /// Higher values provide more margin above ambient noise.
  /// Typical range: 2.0 to 5.0
  /// Default: 3.0
  final double noiseFloorMultiplier;

  /// Minimum time separation between consecutive onset detections (in milliseconds).
  /// Prevents double-detection from the same drum hit.
  /// Must be less than the expected beat interval (e.g., 500ms at 120 BPM).
  /// Typical range: 30ms to 100ms
  /// Default: 50ms
  final double minPeakSeparationMs;

  /// Peak must be this many times above the base threshold to be considered valid.
  /// Provides additional margin against noise fluctuations.
  /// Typical range: 1.2 to 2.0
  /// Default: 1.5
  final double peakStrengthMultiplier;

  /// Cutoff frequency for high-pass filter (in Hz).
  /// Removes low-frequency rumble, handling noise, and DC offset.
  /// Should be well below the lowest drum fundamental frequency (~80-100 Hz).
  /// Typical range: 40Hz to 80Hz
  /// Default: 60Hz
  final double highPassCutoffHz;

  /// Creates onset detection configuration with specified parameters.
  ///
  /// All parameters are optional and have sensible defaults optimized for
  /// typical drum recording scenarios with minimal background noise.
  const OnsetDetectionConfig({
    this.minimumThreshold = 0.15,
    this.noiseFloorMultiplier = 3.0,
    this.minPeakSeparationMs = 50.0,
    this.peakStrengthMultiplier = 1.5,
    this.highPassCutoffHz = 60.0,
  });

  /// Default configuration optimized for typical use cases.
  static const OnsetDetectionConfig defaultConfig = OnsetDetectionConfig();

  @override
  String toString() {
    return 'OnsetDetectionConfig('
        'minimumThreshold: $minimumThreshold, '
        'noiseFloorMultiplier: $noiseFloorMultiplier, '
        'minPeakSeparationMs: $minPeakSeparationMs, '
        'peakStrengthMultiplier: $peakStrengthMultiplier, '
        'highPassCutoffHz: $highPassCutoffHz)';
  }
}

class RhythmAnalyzer {
  static const int fftSize = 2048;
  static const int hopSize = 512;
  static const double sampleRate = 44100;
  static const double minSignalEnergy = 0.001; // Minimum RMS energy to avoid detecting background noise

  // Analyze audio file for rhythm accuracy
  Future<List<TapEvent>> analyzeAudio({
    required String audioFilePath,
    required int bpm,
    required int durationSeconds,
    bool debugMode = false,
    String? debugOutputPath,
    OnsetDetectionConfig config = OnsetDetectionConfig.defaultConfig,
  }) async {
    final debugLog = StringBuffer();

    void log(String message) {
      if (debugMode) {
        debugLog.writeln(message);
      }
      print(message);
    }
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

      log('DEBUG: ========== Audio Analysis Debug Info ==========');
      log('DEBUG: Debug Mode: ${debugMode ? "ENABLED" : "DISABLED"}');
      log('DEBUG: Onset Detection Config: $config');
      log('DEBUG: Total samples loaded: ${samples.length}');
      log('DEBUG: Duration: ${duration.toStringAsFixed(2)}s');
      log('DEBUG: Recording RMS energy: ${rmsEnergy.toStringAsFixed(6)}');
      log('DEBUG: Max amplitude: ${maxAmplitude.toStringAsFixed(6)}');
      log('DEBUG: Minimum required energy: ${minSignalEnergy.toStringAsFixed(6)}');
      log('DEBUG: Energy check: ${rmsEnergy >= minSignalEnergy ? "PASS" : "FAIL"}');

      if (rmsEnergy < minSignalEnergy) {
        // Recording is too quiet or silent - no valid performance detected
        log('WARNING: Recording energy too low (RMS: ${rmsEnergy.toStringAsFixed(6)}). '
            'Please tap louder or check microphone.');
        log('DEBUG: ================================================');
        await _saveDebugLog(debugLog.toString(), debugMode, debugOutputPath);
        return [];
      }

      // Detect onset times (in seconds) with debug information
      log('DEBUG: Starting onset detection with new pipeline...');
      log('DEBUG: Pipeline: High-pass filter → Noise floor → FFT → Spectral flux → Adaptive threshold → Peak picking');
      final onsetData = _detectOnsets(
        samples,
        config: config,
        debugMode: debugMode,
        debugLog: debugLog,
      );
      final onsetTimes = onsetData.map((d) => d['time'] as double).toList();

      log('DEBUG: Detected ${onsetTimes.length} onsets');
      if (onsetTimes.isNotEmpty) {
        log('DEBUG: First few onset times: ${onsetTimes.take(10).map((t) => t.toStringAsFixed(3)).toList()}');
        if (debugMode && onsetData.isNotEmpty) {
          log('DEBUG: Onset details (time, confidence):');
          for (final onset in onsetData.take(10)) {
            log('  ${(onset['time'] as double).toStringAsFixed(3)}s - confidence: ${(onset['confidence'] as double).toStringAsFixed(4)}');
          }
        }
      }

      // Generate expected beat times
      final expectedBeats = _generateExpectedBeats(bpm, durationSeconds);
      log('DEBUG: Expected ${expectedBeats.length} beats for ${durationSeconds}s at $bpm BPM');

      // Match onsets to nearest expected beats
      final tapEvents = _matchOnsetsToBeats(onsetTimes, expectedBeats);
      log('DEBUG: Matched ${tapEvents.length} beats (${((tapEvents.length / expectedBeats.length) * 100).toStringAsFixed(1)}% of expected)');
      log('DEBUG: ================================================');

      // Check for metronome bleed (extremely high consistency)
      // Machine-generated audio loopback (bleed) has near-zero variance (< 1ms).
      // Human playing, even professional, rarely achieves < 5-10ms consistency over 60s.
      // Only check if we have enough data points (at least 3 beats)
      if (tapEvents.length > 2) {
        final consistency = calculateConsistency(tapEvents);
        log('DEBUG: Consistency check: ${consistency.toStringAsFixed(2)}ms');
        if (consistency < 3.0) {
          // It's likely the microphone hearing the metronome speaker
          log('WARNING: Metronome bleed detected');
          await _saveDebugLog(debugLog.toString(), debugMode, debugOutputPath);
          throw MetronomeBleedException(
              'Metronome bleed detected (Consistency: ${consistency.toStringAsFixed(2)}ms). Please use headphones to prevent the microphone from picking up the metronome.');
        }
      }

      // Save debug log if enabled
      await _saveDebugLog(debugLog.toString(), debugMode, debugOutputPath);

      return tapEvents;
    } catch (e, stackTrace) {
      // Log error and return empty list if analysis fails
      print('ERROR: Rhythm analysis failed: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Save debug log to file
  Future<void> _saveDebugLog(String logContent, bool debugMode, String? customPath) async {
    if (!debugMode || logContent.isEmpty) return;

    try {
      final String filePath;
      if (customPath != null) {
        filePath = customPath;
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
        filePath = '${directory.path}/rhythm_analyzer_debug_$timestamp.log';
      }

      final file = File(filePath);
      await file.writeAsString(logContent);
      print('DEBUG: Debug log saved to: $filePath');
    } catch (e) {
      print('ERROR: Failed to save debug log: $e');
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

  // Measure noise floor from the first second of audio
  // Returns RMS energy of the noise sample (0.0 to 1.0 scale)
  // This allows adaptive thresholding based on ambient noise level
  double _measureNoiseFloor(List<double> samples) {
    if (samples.isEmpty) return 0.0;

    // Use first 1 second of audio for noise measurement (44100 samples at 44.1kHz)
    final noiseSampleSize = min(44100, samples.length);
    final noiseSample = samples.sublist(0, noiseSampleSize);

    // Calculate RMS energy of noise sample
    final noiseFloorRMS = _calculateRMS(noiseSample);

    return noiseFloorRMS;
  }

  // Apply first-order high-pass filter to remove DC offset and low-frequency rumble
  // Uses a simple recursive filter: y[n] = alpha * (y[n-1] + x[n] - x[n-1])
  // where alpha = 1 / (1 + 2*pi*fc/fs) determines the cutoff frequency
  // Cutoff frequency (fc) determines which frequencies are attenuated
  List<double> _applyHighPassFilter(List<double> samples, double cutoffHz) {
    if (samples.isEmpty) return samples;

    // Calculate filter coefficient (alpha)
    // alpha approaches 1.0 as cutoff frequency decreases (more filtering)
    // alpha approaches 0.0 as cutoff frequency increases (less filtering)
    final alpha = 1.0 / (1.0 + 2.0 * pi * cutoffHz / sampleRate);

    final filtered = <double>[];
    double previousInput = 0.0;
    double previousOutput = 0.0;

    for (final sample in samples) {
      // First-order high-pass filter difference equation
      final output = alpha * (previousOutput + sample - previousInput);
      filtered.add(output);

      previousInput = sample;
      previousOutput = output;
    }

    return filtered;
  }

  // Calculate adaptive onset threshold based on noise floor
  // The threshold adapts to ambient noise level to prevent false positives
  // in quiet environments while still detecting real drum hits
  //
  // Parameters:
  //   noiseFloorRMS: RMS energy of the first 1 second of audio (0.0 to 1.0)
  //   noiseFloorMultiplier: Multiplier applied to noise floor (from config)
  //   minimumThreshold: Absolute minimum threshold (from config)
  //
  // Formula: threshold = max(noiseFloorRMS * noiseFloorMultiplier + 0.1, minimumThreshold)
  //
  // This ensures:
  // - Threshold is always significantly above noise floor (multiplier determines margin)
  // - Base offset of 0.1 prevents overly sensitive detection
  // - Never goes below minimumThreshold even in perfect silence
  double _calculateAdaptiveThreshold(
    double noiseFloorRMS, {
    required double noiseFloorMultiplier,
    required double minimumThreshold,
  }) {
    // Calculate threshold relative to noise floor
    // Multiplier ensures significant margin above ambient noise
    // 0.1 offset prevents false positives from subtle variations
    final adaptiveThreshold = noiseFloorRMS * noiseFloorMultiplier + 0.1;

    // Ensure threshold never goes below minimum
    // This prevents overly sensitive detection in perfect silence
    final finalThreshold = max(adaptiveThreshold, minimumThreshold);

    return finalThreshold;
  }

  // Pick peaks from spectral flux values with temporal constraints
  // Filters onset candidates to prevent false positives and duplicates
  //
  // Parameters:
  //   fluxValues: List of spectral flux values over time
  //   threshold: Minimum flux value to consider as candidate
  //   minPeakSeparationMs: Minimum time between consecutive peaks (default 50ms)
  //   peakStrengthMultiplier: Peak must be this many times above threshold (default 1.5)
  //
  // Returns: List of onset times (in seconds) that pass all peak picking criteria
  List<double> _pickPeaks(
    List<double> fluxValues, {
    required double threshold,
    double minPeakSeparationMs = 50.0,
    double peakStrengthMultiplier = 1.5,
  }) {
    final peaks = <Map<String, double>>[];
    final strengthThreshold = threshold * peakStrengthMultiplier;

    // Find local maxima that exceed the strength threshold
    for (int i = 1; i < fluxValues.length - 1; i++) {
      final current = fluxValues[i];
      final previous = fluxValues[i - 1];
      final next = fluxValues[i + 1];

      // Check if this is a local maximum
      final isLocalMax = current > previous && current > next;

      // Check if peak exceeds strength threshold
      final isStrongEnough = current >= strengthThreshold;

      if (isLocalMax && isStrongEnough) {
        // Calculate time in seconds for this peak
        // Each frame is separated by hopSize samples
        final timeInSeconds = (i * hopSize) / sampleRate;

        peaks.add({
          'time': timeInSeconds,
          'strength': current,
        });
      }
    }

    // Sort peaks by strength (strongest first)
    peaks.sort((a, b) => (b['strength'] as double).compareTo(a['strength'] as double));

    // Filter peaks by minimum separation time
    final filteredPeaks = <double>[];
    final minSeparationSeconds = minPeakSeparationMs / 1000.0;

    for (final peak in peaks) {
      final peakTime = peak['time'] as double;

      // Check if this peak is far enough from all previously selected peaks
      bool isFarEnough = true;
      for (final selectedTime in filteredPeaks) {
        if ((peakTime - selectedTime).abs() < minSeparationSeconds) {
          isFarEnough = false;
          break;
        }
      }

      if (isFarEnough) {
        filteredPeaks.add(peakTime);
      }
    }

    // Sort by time (chronological order)
    filteredPeaks.sort();

    return filteredPeaks;
  }

  // Calculate frequency-weighted spectral flux
  // Focuses on drum hit frequency range (200Hz-4000Hz) to reduce false positives
  // Uses Half-Wave Rectification (only count energy increases)
  // Returns normalized flux value
  double _calculateSpectralFlux(
    List<double> currentMagnitudes,
    List<double> previousMagnitudes,
  ) {
    // Calculate frequency bin resolution
    // FFT produces fftSize/2 bins from 0 Hz to sampleRate/2 (Nyquist)
    final binResolution = (sampleRate / 2) / (fftSize / 2);

    // Calculate bin indices for frequency ranges
    // Focus on 200Hz-4000Hz (primary drum hit energy)
    // Ignore bins below 200Hz (rumble, handling noise)
    // Ignore bins above 8000Hz (electronic noise, aliasing)
    final minBin = (200 / binResolution).floor();
    final maxBin = min((8000 / binResolution).ceil(), currentMagnitudes.length);

    // Calculate weighted spectral flux
    double flux = 0.0;
    double previousEnergy = 0.0;

    for (int j = minBin; j < maxBin; j++) {
      final diff = currentMagnitudes[j] - previousMagnitudes[j];

      // Half-Wave Rectification: only count increases in energy
      if (diff > 0) {
        // Apply frequency weighting: emphasize 200-4000Hz range
        // Bins between 200-4000Hz get full weight (1.0)
        // Bins between 4000-8000Hz get reduced weight (0.5)
        final binFreq = j * binResolution;
        final weight = binFreq <= 4000 ? 1.0 : 0.5;

        flux += diff * weight;
      }

      previousEnergy += previousMagnitudes[j];
    }

    // Normalize flux by previous frame energy to handle varying volume levels
    // Add small epsilon to avoid division by zero
    final normalizedFlux = previousEnergy > 0
        ? flux / (previousEnergy + 0.0001)
        : 0.0;

    return normalizedFlux;
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
      int dataOffset = -1;
      int dataSize = 0;

      if (riffHeader != 'RIFF') {
        print('DEBUG: Missing RIFF header. Attempting to parse as raw PCM data.');
        // Assume raw PCM (16-bit, Mono, 44.1kHz)
        // Skip 0 bytes header
        dataOffset = 0;
        dataSize = bytes.length;
      } else {
        // Verify WAVE format
        final waveFormat = String.fromCharCodes(bytes.sublist(8, 12));
        if (waveFormat != 'WAVE') {
          print('DEBUG: Not a valid WAV file (missing WAVE format)');
          return [];
        }

        // Find the 'data' chunk by searching through the file
        // WAV files can have multiple chunks (fmt, fact, LIST, INFO, data, etc.)
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

  // Detect onset times using FFT spectral flux with new pipeline
  // Pipeline: High-pass filter → Noise floor → FFT → Spectral flux → Adaptive threshold → Peak picking
  // Returns list of maps with 'time' and 'confidence' (normalized flux value)
  List<Map<String, double>> _detectOnsets(
    List<double> samples, {
    required OnsetDetectionConfig config,
    bool debugMode = false,
    StringBuffer? debugLog,
  }) {
    void debugWrite(String message) {
      if (debugMode && debugLog != null) {
        debugLog.writeln(message);
      }
    }

    debugWrite('DEBUG: ===== Onset Detection Pipeline =====');
    debugWrite('DEBUG: FFT Size: $fftSize, Hop Size: $hopSize');
    debugWrite('DEBUG: Sample Rate: ${sampleRate}Hz');

    if (samples.length < fftSize) {
      return [];
    }

    // Step 1: Measure noise floor from first second of audio
    final noiseFloorRMS = _measureNoiseFloor(samples);
    debugWrite('DEBUG: Noise floor RMS: ${noiseFloorRMS.toStringAsFixed(6)}');

    // Step 2: Apply high-pass filter to remove DC offset and low-frequency rumble
    final filteredSamples = _applyHighPassFilter(samples, config.highPassCutoffHz);
    debugWrite('DEBUG: Applied high-pass filter (${config.highPassCutoffHz} Hz cutoff)');

    // Step 3: Calculate adaptive threshold based on noise floor
    final adaptiveThreshold = _calculateAdaptiveThreshold(
      noiseFloorRMS,
      noiseFloorMultiplier: config.noiseFloorMultiplier,
      minimumThreshold: config.minimumThreshold,
    );
    debugWrite('DEBUG: Adaptive threshold: ${adaptiveThreshold.toStringAsFixed(4)} (noise floor: ${noiseFloorRMS.toStringAsFixed(6)}, multiplier: ${config.noiseFloorMultiplier}, min: ${config.minimumThreshold})');

    // Step 4: FFT sliding window to calculate spectral flux for each frame
    final fft = FFT(fftSize);
    List<double>? previousMagnitudes;
    final fluxValues = <double>[];
    int frameCount = 0;

    debugWrite('DEBUG: Starting FFT sliding window analysis...');

    for (int i = 0; i < filteredSamples.length - fftSize; i += hopSize) {
      frameCount++;
      final window = filteredSamples.sublist(i, i + fftSize);

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
        final normalizedFlux = _calculateSpectralFlux(
          magnitudes,
          previousMagnitudes,
        );
        fluxValues.add(normalizedFlux);

        // Log spectral flux values for debugging (first 20 frames)
        if (debugMode && frameCount <= 20) {
          debugWrite('Frame $frameCount: spectral_flux=${normalizedFlux.toStringAsFixed(4)}, threshold=${adaptiveThreshold.toStringAsFixed(3)}, exceeds=${normalizedFlux > adaptiveThreshold}');
        }
      } else {
        // First frame has no previous frame to compare
        fluxValues.add(0.0);
      }

      previousMagnitudes = magnitudes;
    }

    debugWrite('DEBUG: Total frames processed: $frameCount');
    debugWrite('DEBUG: Total flux values calculated: ${fluxValues.length}');

    // Step 5: Peak picking to find actual onset times
    final onsetTimes = _pickPeaks(
      fluxValues,
      threshold: adaptiveThreshold,
      minPeakSeparationMs: config.minPeakSeparationMs,
      peakStrengthMultiplier: config.peakStrengthMultiplier,
    );

    debugWrite('DEBUG: Total onsets detected after peak picking: ${onsetTimes.length}');

    // Convert onset times to expected format (list of maps with 'time' and 'confidence')
    final onsets = <Map<String, double>>[];
    for (final onsetTime in onsetTimes) {
      // Find the flux value at this onset time to use as confidence
      final frameIndex = ((onsetTime * sampleRate) / hopSize).round();
      final confidence = frameIndex < fluxValues.length ? fluxValues[frameIndex] : 0.0;

      onsets.add({
        'time': onsetTime,
        'confidence': confidence,
      });

      if (debugMode) {
        debugWrite('ONSET DETECTED: time=${onsetTime.toStringAsFixed(3)}s, confidence=${confidence.toStringAsFixed(4)}');
      }
    }

    debugWrite('DEBUG: ===== End Onset Detection =====');

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

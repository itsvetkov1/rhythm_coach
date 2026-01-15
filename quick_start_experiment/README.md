# Quick Start Experiment - Python Diagnostic Tools

This directory contains Python diagnostic tools for analyzing audio recordings and validating the onset detection algorithm.

## Overview

The diagnostic tools help validate the onset detection algorithm by:
- Analyzing audio recordings for noise characteristics
- Comparing old vs new onset detection algorithms
- Visualizing spectral flux, adaptive thresholds, and detected onsets
- Calculating false positive rates and detection accuracy

## Setup

### Python Environment

1. **Create virtual environment** (Python 3.10+ recommended):
   ```bash
   cd quick_start_experiment
   python -m venv venv
   ```

2. **Activate virtual environment**:
   - Windows (PowerShell):
     ```powershell
     .\venv\Scripts\Activate.ps1
     ```
   - Windows (Command Prompt):
     ```cmd
     venv\Scripts\activate.bat
     ```
   - macOS/Linux:
     ```bash
     source venv/bin/activate
     ```

3. **Install dependencies**:
   ```bash
   pip install numpy librosa matplotlib soundfile aubio
   ```

## Tools

### 1. analyze_new_recordings.py

**Purpose**: Compare old (hardcoded threshold) vs new (adaptive + peak picking) onset detection algorithms.

**Features**:
- Noise floor measurement from first 1 second of audio
- Adaptive threshold calculation (noiseFloor × 3.0 + 0.1, min 0.15)
- High-pass filtering (60 Hz cutoff) to remove DC offset and rumble
- Peak picking with temporal constraints (50ms minimum separation)
- Side-by-side visualization of both algorithms
- Summary statistics: false positive rate, detection accuracy

**Usage**:
```bash
cd quick_start_experiment
python analyze_new_recordings.py
```

**Expected Input Files**:
- `test_silence_new.wav` - Complete silence recording (false positive test)
- `test_sound_new.wav` - Background noise recording (false positive test)
- `test_drumming_new.wav` - Actual drumming recording (accuracy test)

**Output**:
- Console output with detailed analysis for each recording
- `onset_detection_comparison.png` - 4-column visualization:
  - Column 1: Waveform with noise floor indicator
  - Column 2: Old algorithm spectral flux with detections
  - Column 3: New algorithm spectral flux with adaptive threshold
  - Column 4: Summary comparison statistics

**Interpreting Results**:

The tool compares two onset detection approaches:

- **Old Algorithm**: Uses hardcoded threshold of 0.25 on spectral flux
  - Simple but produces false positives in quiet environments
  - Cannot adapt to different noise levels

- **New Algorithm**: Uses 5-step adaptive pipeline
  1. Measure noise floor from first 1 second
  2. Apply high-pass filter (60 Hz cutoff)
  3. Calculate spectral flux with frequency weighting
  4. Calculate adaptive threshold: `max(noiseFloor × 3.0 + 0.1, 0.15)`
  5. Pick peaks with 50ms minimum separation and 1.5× strength requirement

**Success Criteria**:
- Silence test: 0 detected onsets (no false positives)
- Noise test: 0 detected onsets (no false positives)
- Drumming test: ≥95% of actual drum hits detected

### 2. analyze_drum_practice.py

**Purpose**: Aubio-based onset detection analysis for validating drum practice recordings.

**Usage**:
```bash
python analyze_drum_practice.py <audio_file.wav>
```

### 3. diagnose_false_positives.py

**Purpose**: Detect AGC artifacts, clipping, and false positive sources in recordings.

**Usage**:
```bash
python diagnose_false_positives.py <audio_file.wav>
```

## Typical Workflow

### Validating New Onset Detection Algorithm

1. **Record test audio** on Android device:
   - Record 5+ seconds of complete silence
   - Record 5+ seconds with background noise (no drumming)
   - Record actual drumming at consistent tempo

2. **Copy recordings** to `quick_start_experiment/` directory:
   ```bash
   # Example using adb
   adb pull /storage/emulated/0/Android/data/com.rhythmcoach.ai_rhythm_coach/files/test_silence_new.wav
   adb pull /storage/emulated/0/Android/data/com.rhythmcoach.ai_rhythm_coach/files/test_sound_new.wav
   adb pull /storage/emulated/0/Android/data/com.rhythmcoach.ai_rhythm_coach/files/test_drumming_new.wav
   ```

3. **Run analysis**:
   ```bash
   cd quick_start_experiment
   source venv/Scripts/activate  # or .\venv\Scripts\Activate.ps1 on Windows
   python analyze_new_recordings.py
   ```

4. **Review results**:
   - Check console output for false positive counts
   - Open `onset_detection_comparison.png` to visualize algorithm behavior
   - Verify new algorithm eliminates false positives while maintaining accuracy

5. **Tune parameters** (if needed):
   - If false positives persist, increase `noiseFloorMultiplier` or `minimumThreshold`
   - If missing real drum hits, decrease thresholds or `peakStrengthMultiplier`
   - Adjust `minPeakSeparationMs` if double-detections occur

## Algorithm Parameters

The new onset detection algorithm uses these configurable parameters (defined in `lib/services/rhythm_analyzer.dart`):

| Parameter | Default | Purpose | Typical Range |
|-----------|---------|---------|---------------|
| `minimumThreshold` | 0.15 | Absolute minimum for spectral flux threshold | 0.10 - 0.25 |
| `noiseFloorMultiplier` | 3.0 | Adaptive threshold = noiseFloor × this + 0.1 | 2.0 - 5.0 |
| `minPeakSeparationMs` | 50.0 | Minimum time between detected peaks (prevents doubles) | 30 - 100 ms |
| `peakStrengthMultiplier` | 1.5 | Peak must be this many times above threshold | 1.2 - 2.0 |
| `highPassCutoffHz` | 60.0 | Cutoff frequency to remove rumble and DC offset | 40 - 100 Hz |

## Troubleshooting

### "ModuleNotFoundError: No module named 'numpy'"
Install dependencies: `pip install numpy librosa matplotlib soundfile aubio`

### "FileNotFoundError: test_silence_new.wav"
The script expects specific WAV files. Either:
- Create recordings with these exact filenames, OR
- Edit the `recordings` list in `analyze_new_recordings.py` to match your files

### Visualization not showing
The script saves to `onset_detection_comparison.png` in the current directory. Open it with an image viewer.

### High false positive rate with new algorithm
The algorithm may need tuning for your specific recording environment:
- Check noise floor measurements in console output
- If noise floor > 0.05, environment is very noisy
- Increase `minimumThreshold` or `noiseFloorMultiplier` in Dart code
- Re-run tests to validate changes

## References

The onset detection algorithm is based on established music information retrieval (MIR) research:
- **Spectral Flux**: Measures changes in frequency spectrum over time
- **Half-Wave Rectification**: Only count energy increases (onset = sudden energy rise)
- **Adaptive Thresholding**: Noise-relative thresholds prevent false positives
- **Peak Picking**: Local maxima with temporal constraints
- **High-Pass Filtering**: Remove low-frequency noise before analysis

For more details, see:
- `PRD.md` - Complete product requirements and algorithm design
- `CLAUDE_SESSION_LOG.md` - Development history and technical decisions
- `lib/services/rhythm_analyzer.dart` - Implementation in Dart/Flutter

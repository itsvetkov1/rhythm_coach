# AI Assistant for Musical Structure Recognition - Analysis & Implementation Guide

**Team:** 2 Musicians + 1 Developer
**Goal:** Real-time feedback on musical structure (chords, melody, rhythm)
**Constraints:** MVP with minimum viable dataset, scalable to 500+ samples

---

## Opensource Tools Landscape

| Tool/Model | Pretrained For | Fine-tunable | Real-time | Team-Friendly | Assessment |
|------------|----------------|--------------|-----------|---------------|------------|
| **Basic Pitch** (Spotify) | Melody/polyphonic transcription | Yes | Yes | Yes | Lightweight (<17K params), instrument-agnostic, excellent for melody |
| **Madmom** | Chord recognition, beat/tempo tracking, onset detection | Yes | Yes | Yes | Complete MIR suite with pretrained ML models, Python-friendly |
| **CREPE** | Monophonic pitch tracking | Limited | Yes | Yes | State-of-art pitch, multiple model sizes, GPU-accelerated |
| **Aubio** | Onset, beat, pitch tracking | No | Yes | Yes | Fast C library, real-time focus, no ML models but reliable |
| **Essentia** | Comprehensive feature extraction | Yes | Yes | Moderate | Extensive algorithms, deep learning support, steeper curve |
| **ChordMini** (2025) | Chord recognition (301 labels), beat tracking | Limited | Yes | Yes | Recent tool, comprehensive chord vocabulary, LLM-powered analysis |
| **Librosa** | Feature extraction only | N/A | No | Yes | Excellent for preprocessing, no pretrained models, batch-only |
| **Magenta (Google)** | Piano transcription, melody/drum generation | Yes | Limited | Moderate | Powerful but resource-heavy, strong for melody, limited real-time |

---

## Top 5 Approaches (Ranked)

### 1. Hybrid Pretrained Stack (Basic Pitch + Madmom + Aubio) - Quality: 8/10 - Efficiency: 9/10

**Overview:** Combine three specialized pretrained tools into a unified pipeline: Basic Pitch for melody transcription, Madmom for chord recognition, and Aubio for rhythm/beat tracking. Each component handles one aspect of musical structure, with minimal custom training required. Fine-tune Madmom's chord model on your recordings while using the other tools out-of-box.

**Opensource Baseline:**
- Basic Pitch (Spotify) - melody
- Madmom DCN Chord Recognition - chords
- Aubio beat tracker - rhythm

**Training Strategy:**
Pretrained + selective fine-tuning. Use Basic Pitch and Aubio as-is (already general-purpose). Fine-tune only Madmom's chord model on 100-200 annotated samples of your specific musical context (genre, instruments, playing style). Apply data augmentation (pitch shift ±2 semitones, tempo stretch 0.9-1.1x, light noise) to multiply effective dataset 5-10x.

**Minimum Data for MVP:**
- Samples: 100 chord progressions (30 seconds each)
- Variations: 3 keys, 2 tempos (slow/fast), 2 playing styles (clean/complex voicings)
- Recording specs: WAV, 44.1kHz, 24-bit, mono (for single instrument) or stereo (for ensemble)

**Real-time Feasibility:**
- Expected latency: 40-80ms (combined pipeline)
- Compute: CPU-only capable, GPU accelerates to <40ms
- Optimizations: Run components in parallel threads, use Madmom's "small" model variant, implement circular buffer for streaming audio

**Team Effort:**
- Dev implementation: 60-80 hours (integration, API design, real-time optimization, testing)
- Musician recording: 15-20 hours (100 progressions × 3 variations × 30s + annotation time)
- Maintenance: Low (stable libraries, minimal retraining)

**Quality-Efficiency Tradeoff:**
- Excels at: Broad instrument coverage, balanced accuracy across all three tasks, minimal training data needed
- Compromises on: Slightly lower chord accuracy than single-focus systems, integration complexity (3 separate tools)
- Failure modes: Struggles with extremely dense polyphony (>6 simultaneous notes), uncommon chord extensions (maj13, altered dominants), syncopated rhythms with heavy swing

---

### 2. Fine-tuned Madmom All-in-One - Quality: 7/10 - Efficiency: 8/10

**Overview:** Use Madmom as the sole framework since it provides pretrained models for all three tasks (chord recognition via Deep Chroma Network, beat tracking via RNN DBN, onset detection via CNN). Fine-tune the chord and beat models on custom recordings while leveraging shared audio representations. Simplifies architecture to single library.

**Opensource Baseline:**
Madmom library with DCN (Deep Chroma Network) for chords, RNNDownBeatProcessor for rhythm

**Training Strategy:**
Transfer learning on Madmom's pretrained models. Fine-tune chord model on 150-250 samples, beat model on 50-100 samples. Use Madmom's built-in feature extractors (log-filtered spectrogram, deep chroma) as frozen layers, retrain only final classification layers. Heavy augmentation (tempo ±15%, pitch ±3 semitones, dynamic range compression).

**Minimum Data for MVP:**
- Samples: 150 chord progressions (20-40s each), 50 rhythm patterns (30s each)
- Variations: 4 keys, 3 tempo ranges (slow/medium/fast), varied dynamics
- Recording specs: WAV, 44.1kHz, 16-bit minimum, mono preferred

**Real-time Feasibility:**
- Expected latency: 50-100ms (single-library overhead advantage)
- Compute: CPU sufficient for beat/onset, GPU recommended for chord recognition
- Optimizations: Use Madmom's streaming mode, reduce hop size to 512 samples (23ms at 22kHz)

**Team Effort:**
- Dev implementation: 40-50 hours (single library reduces integration, focus on fine-tuning pipeline)
- Musician recording: 20-25 hours (200 total samples + annotation)
- Maintenance: Very low (unified codebase, single dependency)

**Quality-Efficiency Tradeoff:**
- Excels at: Unified architecture simplicity, fast development, excellent beat/tempo tracking
- Compromises on: Chord vocabulary limited to 25 types (vs ChordMini's 301), melody transcription not included (only chord recognition)
- Failure modes: Weak on complex jazz chords (9th, 11th, 13th extensions), struggles with non-Western tuning systems, rhythm detection fails on extreme tempo changes (>150% swing)

---

### 3. Magenta Transfer Learning with Chord-Conditioned Models - Quality: 8/10 - Efficiency: 6/10

**Overview:** Leverage Google Magenta's Music Transformer and chord-conditioned MusicRNN models for melody transcription and structure analysis. Use Magenta's Onsets and Frames for note-level transcription, then apply chord estimation on top. Requires TensorFlow expertise but offers state-of-art melody quality. Combine with Aubio for rhythm.

**Opensource Baseline:**
Magenta Onsets and Frames (melody), Magenta MusicVAE with ChordEncoder (structure), Aubio (rhythm)

**Training Strategy:**
Fine-tune Onsets and Frames on 200-300 annotated MIDI+audio pairs. Use Magenta's chord-conditioned models with custom chord vocabulary training (100 samples). Hybrid approach: pretrained Onsets and Frames for melody, train chord classifier from deep features, use Aubio as-is for rhythm.

**Minimum Data for MVP:**
- Samples: 250 recordings with MIDI ground truth (melody) + 100 chord-annotated samples
- Variations: Instrument-specific (piano/guitar best, requires separate models for other instruments)
- Recording specs: WAV 16kHz (for Magenta), 44.1kHz source downsampled, mono per instrument

**Real-time Feasibility:**
- Expected latency: 80-150ms (Magenta models are heavier)
- Compute: GPU required (model has 54M parameters for full transformer)
- Optimizations: Use smaller Onsets and Frames variant, TensorFlow Lite for mobile/edge, frame-level processing with lookahead buffer

**Team Effort:**
- Dev implementation: 80-100 hours (TensorFlow expertise needed, complex model tuning, MIDI annotation tools)
- Musician recording: 35-40 hours (250 samples + MIDI annotation is time-intensive)
- Maintenance: Moderate (TensorFlow version dependencies, model serving complexity)

**Quality-Efficiency Tradeoff:**
- Excels at: Best-in-class melody transcription (especially piano), strong harmonic understanding, handles complex polyphony
- Compromises on: High computational cost, requires MIDI annotation (more musician effort), limited instrument generalization
- Failure modes: Poor generalization across instrument timbres (piano-trained model fails on guitar), struggles with percussive instruments, high latency makes true real-time difficult without GPU

---

### 4. ChordMini + Essentia Feature Hybrid - Quality: 7/10 - Efficiency: 7/10

**Overview:** Use ChordMini's recent 2025 chord recognition system (301 chord labels) as the chord engine, Essentia's comprehensive feature extraction for melody/pitch tracking, and Essentia's rhythm descriptors for beat analysis. Build thin custom layer on top to unify outputs. Leverages newest tools with extensive chord vocabulary.

**Opensource Baseline:**
ChordMini (Chord-CNN-LSTM + BTC models), Essentia PitchYinProbabilistic + RhythmExtractor2013

**Training Strategy:**
Minimal training. Use ChordMini out-of-box (already supports 301 chord types including inversions). Fine-tune Essentia's pitch tracking on 50-100 samples if needed. Build custom decision layer (lightweight classifier, <1000 parameters) to combine outputs into unified structure representation. Data augmentation for decision layer training only.

**Minimum Data for MVP:**
- Samples: 50-100 for decision layer training (ChordMini and Essentia used pretrained)
- Variations: Focus on edge cases where tools disagree (polyrhythms, extended chords, pitch bends)
- Recording specs: WAV, 44.1kHz or 48kHz, 24-bit, stereo

**Real-time Feasibility:**
- Expected latency: 60-100ms (ChordMini BTC model optimized for real-time)
- Compute: CPU capable, benefits from GPU
- Optimizations: ChordMini includes beat-synchronous processing, Essentia has streaming mode

**Team Effort:**
- Dev implementation: 50-60 hours (integration of ChordMini + Essentia, custom decision layer)
- Musician recording: 10-12 hours (minimal training data, focus on validation set)
- Maintenance: Moderate (ChordMini is new/2025, potential API changes, Essentia is mature/stable)

**Quality-Efficiency Tradeoff:**
- Excels at: Comprehensive chord vocabulary (301 types vs typical 25), includes inversions and extensions, strong tonal modulation detection (LLM-powered in ChordMini)
- Compromises on: ChordMini very new (less battle-tested), integration complexity (Python + potentially JS/web components), melody transcription not as strong as dedicated tools
- Failure modes: ChordMini may have bugs (2025 release), Essentia pitch tracking weaker on polyphonic sources, no unified melody representation (just pitch tracks, not note sequences)

---

### 5. Lightweight Custom CNN with Heavy Augmentation - Quality: 6/10 - Efficiency: 5/10

**Overview:** Train a custom small-footprint CNN from scratch (inspired by CREPE/Basic Pitch architectures) specifically for your musical context. Use <50K parameters for fast inference. Compensate for small dataset with aggressive augmentation pipeline (pitch, tempo, noise, eq, compression, room simulation). Full control over architecture but requires ML expertise.

**Opensource Baseline:**
Custom build: 1D CNN (6 conv layers, ~30K params) → example architecture: [Conv1D(64) → Conv1D(128) → Conv1D(256)] × 2 + Dense layers

**Training Strategy:**
Train from scratch with massive augmentation. Build three task-specific heads (chord classifier, pitch regressor, beat detector) sharing convolutional feature extractor. Augmentation multiplier: 20-50x (pitch shift ±4 semitones in 0.5 steps, tempo 0.75-1.25x, add noise/reverb/eq, mixup between samples). Requires 100-200 base samples, becomes 2000-10000 effective samples post-augmentation.

**Minimum Data for MVP:**
- Samples: 100-200 carefully curated base recordings
- Variations: Maximize diversity in base set (10+ chord types, 5+ melodic patterns, 5+ rhythm styles), augmentation handles variations
- Recording specs: WAV, 22kHz (lower rate reduces compute), 16-bit, mono

**Real-time Feasibility:**
- Expected latency: 20-40ms (lightweight architecture advantage)
- Compute: CPU-only capable (30K params), extremely fast on GPU (<10ms)
- Optimizations: Model designed for real-time (causal convolutions, no lookahead), quantization to INT8 for mobile/edge

**Team Effort:**
- Dev implementation: 100-120 hours (model design, training pipeline, augmentation experiments, hyperparameter tuning)
- Musician recording: 12-15 hours (fewer samples but need high quality + careful annotation)
- Maintenance: High (custom model requires ongoing tuning, no community support)

**Quality-Efficiency Tradeoff:**
- Excels at: Lowest latency, custom-fit to exact use case, full architecture control, tiny model size (<5MB)
- Compromises on: Lower absolute accuracy (6/10 vs 8/10 for pretrained), requires strong ML expertise, risky (may fail to converge with small data), high upfront dev cost
- Failure modes: Overfitting despite augmentation (especially with <100 base samples), poor generalization outside training distribution, difficult to debug (no baselines), augmentation artifacts if too aggressive

---

## Recommended MVP Implementation (Approach #1: Hybrid Pretrained Stack)

**Chosen Approach:** Hybrid Pretrained Stack (Basic Pitch + Madmom + Aubio)

**Why This Approach:** Optimal for a 3-person team with limited ML infrastructure. Leverages battle-tested opensource tools with minimal training requirements, allowing the developer to focus on integration rather than ML expertise. The 2 musicians can contribute high-quality recordings without extensive annotation burden. Balances quality (8/10) and efficiency (9/10) better than alternatives. Real-world proven components reduce risk of implementation failure.

### Architecture/Model

```
Audio Input (real-time stream)
    ↓
[Buffer Manager] (circular buffer, 2048 samples @ 44.1kHz = ~46ms chunks)
    ↓
    ├─→ [Basic Pitch] → MIDI note events + pitch bends → Melody Structure
    ├─→ [Madmom DCN] → Chord labels (25 types) → Harmonic Structure
    └─→ [Aubio Beat Tracker] → Beat times + tempo → Rhythmic Structure
    ↓
[Fusion Layer] (align outputs to common timeline, resolve conflicts)
    ↓
[Real-time Feedback API] → Visual display / audio cues / MIDI output
```

### Step-by-Step Implementation

#### 1. Environment Setup

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install core dependencies
pip install basic-pitch==0.3.0 madmom==0.17.dev0 aubio==0.4.9
pip install numpy scipy librosa soundfile pyaudio
pip install tensorflow>=2.0  # for Basic Pitch

# Verify installations
python -c "import basic_pitch, madmom, aubio; print('All imports successful')"
```

#### 2. Data Preparation & Annotation

```python
# Create annotation tool for chord labeling
# scripts/annotate_chords.py
import soundfile as sf
import matplotlib.pyplot as plt

# Musicians use this to label chord boundaries and types
# Output: JSON with {start_time, end_time, chord_label}
# Example: [{"start": 0.0, "end": 2.5, "chord": "Cmaj7"}, ...]
```

- Record 100 chord progressions (30s each, ~50 minutes total audio)
- Use simple DAW (Audacity/Reaper) with click track
- Annotate chord changes using custom tool or JAMS format
- Split 80/20 train/validation

#### 3. Fine-tune Madmom Chord Model

```python
# scripts/finetune_madmom.py
from madmom.features.chords import DeepChromaProcessor, CNNChordFeatureProcessor
from madmom.ml.nn import NeuralNetwork
import numpy as np

# Load pretrained Madmom model
dcp = DeepChromaProcessor()

# Extract features from training data
features = [dcp(audio_file) for audio_file in train_files]

# Fine-tune classification layer (keep feature extractor frozen)
# Train on your 100 annotated samples with augmentation
# Use Adam optimizer, learning rate 1e-4, 50 epochs
```

#### 4. Build Real-time Integration

```python
# src/realtime_analyzer.py
import pyaudio
import numpy as np
from basic_pitch.inference import predict
from madmom.features.chords import DeepChromaChordRecognitionProcessor
from aubio import tempo, onset
import threading
from collections import deque

class MusicStructureAnalyzer:
    def __init__(self, sample_rate=44100, buffer_size=2048):
        self.sr = sample_rate
        self.buffer_size = buffer_size

        # Initialize components
        self.chord_processor = DeepChromaChordRecognitionProcessor()
        self.tempo_detector = tempo("default", buffer_size, buffer_size//4, sr)
        self.audio_buffer = deque(maxlen=sample_rate*2)  # 2-second buffer

        # Threading for parallel processing
        self.melody_thread = None
        self.chord_thread = None
        self.rhythm_thread = None

    def process_chunk(self, audio_chunk):
        """Process incoming audio chunk in real-time"""
        self.audio_buffer.extend(audio_chunk)

        # Run processors in parallel threads
        results = {}
        with ThreadPoolExecutor(max_workers=3) as executor:
            melody_future = executor.submit(self.detect_melody, audio_chunk)
            chord_future = executor.submit(self.detect_chords, audio_chunk)
            rhythm_future = executor.submit(self.detect_rhythm, audio_chunk)

            results['melody'] = melody_future.result()
            results['chords'] = chord_future.result()
            results['rhythm'] = rhythm_future.result()

        return self.fuse_results(results)
```

#### 5. Testing & Validation

```python
# tests/test_accuracy.py
from sklearn.metrics import f1_score, accuracy_score

# Evaluate on validation set (20 held-out samples)
def evaluate_system(test_files, ground_truth):
    predictions = [analyzer.process_file(f) for f in test_files]

    # Chord accuracy (frame-level, 10ms resolution)
    chord_acc = accuracy_score(gt_chords, pred_chords)

    # Melody F1 (note-level, onset tolerance ±50ms)
    melody_f1 = compute_note_f1(gt_notes, pred_notes, tolerance=0.05)

    # Beat F1 (onset tolerance ±70ms)
    beat_f1 = compute_beat_f1(gt_beats, pred_beats, tolerance=0.07)

    return {'chord_acc': chord_acc, 'melody_f1': melody_f1, 'beat_f1': beat_f1}
```

### Technical Requirements

**Hardware:**
- CPU: 4+ cores (Intel i5/AMD Ryzen 5 or better) for parallel processing
- RAM: 8GB minimum (16GB recommended for comfortable development)
- GPU: Optional but recommended (NVIDIA GTX 1650 or better reduces latency to <40ms)
- Audio Interface: Any class-compliant USB interface (Focusrite Scarlett, Behringer UMC series)

**Software:**
- Python 3.8-3.10 (TensorFlow compatibility)
- TensorFlow 2.8+ or PyTorch 1.13+ (for Basic Pitch)
- PyAudio or SoundDevice (for real-time audio capture)
- OS: Linux/macOS preferred for lower audio latency, Windows 10+ works with ASIO4ALL

**Environment:**
- Virtual environment (venv/conda) for dependency isolation
- Git for version control
- VSCode/PyCharm with Python debugging support

---

## Data Collection Plan

### For Musicians

#### What to Record

1. **Chord Progressions (100 samples)**
   - Common progressions in your genre (ii-V-I, I-IV-V, etc.)
   - Include simple triads AND extended chords (7th, 9th, add9, sus4)
   - Record both strummed/blocked and arpeggiated versions
   - Duration: 30 seconds per sample

2. **Melodic Phrases (50 samples)**
   - Short melodic motifs (2-4 bars)
   - Range: at least 1.5 octaves
   - Include stepwise motion AND leaps
   - Both legato and staccato articulations
   - Duration: 15-20 seconds per sample

3. **Rhythm Patterns (30 samples)**
   - Various time signatures (4/4, 3/4, 6/8)
   - Different subdivision feels (straight, swing, shuffle)
   - Tempo range: 60-180 BPM
   - Duration: 20-30 seconds per sample

#### Variations Needed

- **Keys:** Record each progression/melody in 3 different keys (C, G, F recommended for guitar; C, F, Bb for horns)
- **Tempos:** Slow (60-80 BPM), Medium (100-120 BPM), Fast (140-160 BPM)
- **Dynamics:** Soft/medium/loud playing
- **Playing Styles:**
  - Guitar: Fingerpicked vs strummed, clean vs overdriven
  - Piano: Soft pedal vs sustain pedal, different velocities
  - Vocals: Breathy vs belted, vibrato vs straight tone
- **Articulation:** Legato (smooth), staccato (detached), accented

#### Duration per Sample

- Chord progressions: 30 seconds × 100 = 50 minutes
- Melodies: 20 seconds × 50 = 17 minutes
- Rhythms: 25 seconds × 30 = 12 minutes
- **Total raw recording time: ~80 minutes**

#### Total Recording Time (including setup, retakes, annotation)

- Recording sessions: ~6 hours (with breaks, retakes, tuning)
- Annotation: ~10 hours (labeling chords, marking beats, checking MIDI alignment)
- **Total: 16-20 hours** musician time

### Technical Specs

- **Format:** WAV (uncompressed, lossless)
- **Sample Rate:** 44.1kHz (CD quality, balance between file size and quality)
- **Bit Depth:** 24-bit (captures full dynamic range, critical for quiet passages)
- **Channels:** Mono for single instruments (guitar, vocal, sax), Stereo for piano/keyboard
  - *Why:* Mono reduces computational load and most models expect mono; stereo only if natural instrument spread matters

**Recording Setup:**
- Quiet room (minimize background noise)
- Consistent mic placement across sessions
- Record dry signal (no reverb/effects) - add these as augmentation later
- Use click track or metronome for rhythm samples
- Leave 1-second silence before/after each sample

### Minimum Dataset

- **MVP:** 100 total samples (60 chord + 30 melody + 10 rhythm)
  - Achievable in 8-10 hours musician time
  - Enough to fine-tune Madmom chord model
  - Use Basic Pitch and Aubio out-of-box

- **Optimal:** 250 total samples (150 chord + 70 melody + 30 rhythm)
  - 18-22 hours musician time
  - Significantly improves fine-tuned model accuracy
  - Allows proper train/val/test split (70/15/15)

### Data Augmentation

Apply these transformations to multiply dataset size **without additional recording**:

#### Techniques

1. **Pitch Shifting:** ±2 semitones in 0.5-semitone steps (9 variations per sample)
   - Tool: `librosa.effects.pitch_shift()` or `sox`
   - Preserves rhythm and structure while expanding key coverage

2. **Time Stretching:** 0.9x, 1.0x, 1.1x tempo (3 variations)
   - Tool: `librosa.effects.time_stretch()` or `rubberband`
   - Don't stretch >±10% to avoid artifacts

3. **Noise Injection:** Add white noise at -40dB, -50dB, -60dB SNR (3 variations)
   - Simulates different recording conditions
   - Improves model robustness

4. **EQ Variations:** Boost/cut bass (-3dB @ 200Hz) and treble (+3dB @ 5kHz) (2 variations)
   - Simulates different instruments/mic positions

5. **Dynamic Range Compression:** Light compression (3:1 ratio) (1 variation)
   - Simulates different playing dynamics

#### Multiplier Effect

- Conservative: 9 (pitch) × 3 (tempo) = 27x → 100 samples become 2,700
- Aggressive: 9 × 3 × 3 (noise) × 2 (EQ) = 162x → 100 samples become 16,200

**Recommended:** Use 27-50x multiplier for MVP (balance quality vs variety)

#### Implementation

```python
# scripts/augment_dataset.py
import librosa
import numpy as np

def augment_sample(audio_path):
    y, sr = librosa.load(audio_path, sr=44100)
    augmented = []

    for pitch_shift in [-2, -1, 0, 1, 2]:  # ±2 semitones
        y_pitch = librosa.effects.pitch_shift(y, sr=sr, n_steps=pitch_shift)

        for tempo_stretch in [0.9, 1.0, 1.1]:  # ±10% tempo
            y_aug = librosa.effects.time_stretch(y_pitch, rate=tempo_stretch)
            augmented.append(y_aug)

    return augmented  # Returns 15 variations per sample
```

---

## Expected Results

### Quantitative Metrics

**MVP Targets (after 100 base samples + augmentation):**
- **Chord recognition accuracy:** 70-75% (frame-level, 10ms resolution)
  - Industry baseline: 65-70% for general-purpose systems
  - Fine-tuning on your data should reach 70-75%

- **Melody transcription F1:** 0.65-0.72 (note-level, ±50ms onset tolerance)
  - Basic Pitch out-of-box: ~0.70 F1 on mixed instruments
  - Your context may vary ±0.05 depending on instrument

- **Beat detection F1:** 0.85-0.92 (±70ms tolerance)
  - Aubio is very strong on beat tracking (industry: 0.80-0.90)
  - Should reach high 0.80s even without training

- **Real-time latency:** 60-80ms (CPU), 35-50ms (GPU)
  - Basic Pitch: ~25-40ms
  - Madmom: ~20-30ms
  - Aubio: ~5-10ms
  - Integration overhead: ~10-20ms

**Production Targets (after 250+ samples, optimized):**
- Chord accuracy: 78-85%
- Melody F1: 0.75-0.80
- Beat F1: 0.90-0.95
- Latency: <50ms (with GPU optimization)

### Qualitative Expectations

**MVP "Good Enough" means:**
- Correctly identifies 7 out of 10 chord changes in real-time
- Captures main melody notes (may miss grace notes or fast ornaments)
- Locks onto beat/tempo reliably after 2-4 bars
- Provides usable feedback for practice/performance
- Fails gracefully (doesn't crash on edge cases)

**Production Ready means:**
- Correctly identifies 8+ out of 10 chords including some extensions (7ths, 9ths)
- Accurately transcribes melody with <5% note errors
- Beat tracking stable even with tempo fluctuations (±5% BPM variance)
- Handles polyphonic instruments (piano, guitar) with 2-4 simultaneous notes
- Provides actionable feedback (e.g., "you're rushing the beat," "that's a Dm7 not Dm")

### Failure Modes & Recognition

**When the system struggles:**

1. **Dense Polyphony (>4 simultaneous notes)**
   - Recognition: Chord output oscillates rapidly, melody transcription produces clusters of notes
   - Workaround: Focus on simpler arrangements for MVP, or isolate melody track

2. **Uncommon Chord Extensions (maj13, altered dominants, polychords)**
   - Recognition: System labels as "simpler" chord (Cmaj13 → Cmaj7)
   - Workaround: Accept reduced chord vocabulary for MVP, or manually annotate these as separate class

3. **Extreme Tempo Variations (rubato, fermatas, sudden tempo changes >20%)**
   - Recognition: Beat tracker loses sync, needs 4-8 bars to recover
   - Workaround: Train on examples with tempo variation, or implement manual beat reset button

4. **Noisy/Distorted Audio (heavy overdrive, room reverb)**
   - Recognition: Chord accuracy drops >20%, melody transcription produces spurious notes
   - Workaround: Record cleaner signals for training, add noise augmentation

5. **Microtonal/Non-Western Tuning**
   - Recognition: All pitch-based features fail (nearest semitone quantization errors)
   - Workaround: Out of scope for MVP (requires specialized models)

### Success vs. Pivot Criteria

**✅ SUCCESS - Continue with Approach #1 if:**
- Chord accuracy >65% on validation set after fine-tuning
- Melody F1 >0.60 on your instrument
- Beat tracking locks within 4 bars consistently
- Real-time latency <100ms on your hardware
- Musicians find feedback useful in practice

**🔄 PIVOT - Try Approach #2 (Madmom All-in-One) if:**
- Integration complexity too high (spending >40 hours just on component communication)
- Basic Pitch melody transcription poor on your instrument (<0.55 F1)
- Latency budget exceeded (>120ms even on GPU)

**🔄 PIVOT - Try Approach #4 (ChordMini + Essentia) if:**
- Need richer chord vocabulary (current 25 types insufficient)
- Madmom chord accuracy stuck <60% even after fine-tuning

**🔄 PIVOT - Reconsider Requirements if:**
- Can't collect 100 samples in reasonable time
- Real-time requirement relaxable (batch analysis acceptable)
- Hardware constraints too severe (<4GB RAM, no GPU option)

---

## Summary

The **Hybrid Pretrained Stack (Approach #1)** offers the best balance for your team. Start with 100 recordings (16-20 musician-hours), fine-tune Madmom's chord model, and integrate three mature opensource tools. Expect 70-75% chord accuracy, 0.65-0.72 melody F1, and 0.85-0.92 beat F1 with 60-80ms latency.

If integration proves too complex, pivot to **Madmom All-in-One (Approach #2)**. If chord vocabulary is limiting, add **ChordMini (Approach #4)**.

---

## Sources

- [GitHub - chord-recognition topics](https://github.com/topics/chord-recognition)
- [Open source chord & beat detection application - DEV Community](https://dev.to/ngha_phantrng_ccdda2bf/open-source-chord-beat-detection-application-39f5)
- [GitHub - mxkrn/webchord: Real-time chord detection](https://github.com/mxkrn/webchord)
- [madmom: A New Python Audio and Music Signal Processing Library (ACM)](https://dl.acm.org/doi/10.1145/2964284.2973795)
- [madmom research paper (PDF)](https://www.cp.jku.at/research/papers/Boeck_etal_ACMMM_2016.pdf)
- [Essentia documentation](https://essentia.upf.edu/)
- [Magenta Music documentation](https://magenta.github.io/magenta-js/music/)
- [Exploring Music Transcription with Multi-Modal Language Models - Medium](https://medium.com/data-science/exploring-music-transcription-with-multi-modal-language-models-af352105db56)
- [Music Transformer: Generating Music with Long-Term Structure - Magenta](https://magenta.withgoogle.com/music-transformer)
- [GitHub - ISMIR2019 Large-Vocabulary Chord Recognition](https://github.com/music-x-lab/ISMIR2019-Large-Vocabulary-Chord-Recognition)
- [Basic Pitch: Spotify's Open Source Audio-to-MIDI Converter](https://engineering.atspotify.com/2022/6/meet-basic-pitch)
- [GitHub - spotify/basic-pitch](https://github.com/spotify/basic-pitch)
- [Basic Pitch Demo](https://basicpitch.spotify.com/)
- [GitHub - marl/crepe: CREPE pitch estimation](https://github.com/marl/crepe)
- [torchcrepe PyPI](https://pypi.org/project/torchcrepe/)
- [CREPE: A Convolutional Representation for Pitch Estimation (arXiv)](https://arxiv.org/abs/1802.06182)
- [aubio - library for audio labelling](https://aubio.org/)
- [GitHub - aubio/aubio](https://github.com/aubio/aubio)
- [Real Time Beat Prediction with Aubio](https://www.maxhaesslein.de/notes/real-time-beat-prediction-with-aubio/)

# AI Music Recognition Learning Plan - Enhanced Prompt

## Quick Reference

**Purpose**: Guide a developer through a 3-5 hour hands-on experiment to evaluate if Basic Pitch + Madmom + Aubio will work for their rhythm coach project, with Claude Code writing most code.

**Output**:
1. Working proof-of-concept script that processes audio files and outputs chord/melody/rhythm analysis
2. Comprehensive documentation outlining full learning roadmap for future deep dives
3. Viability assessment: "Will this work for my rhythm coach project?"

**Key Requirements**:
- Complete setup and working example in 3-5 hours
- Claude Code writes all code - student just runs and validates
- Install → Run → Understand outputs → Assess viability
- Create structured documentation for all future learning paths discussed
- Focus on proof-of-concept, not deep understanding

**Critical Rules**:
- No deep ML theory - just load pretrained models and use them
- Skip fundamentals (FFT, spectrograms) unless needed to understand outputs
- All code must be copy-paste ready
- Document full curriculum structure for later reference

---

## Full Specification

**CONTEXT:**

You are creating a **rapid experimentation guide** for a developer using Claude Code to evaluate whether the "Hybrid Pretrained Stack" (Basic Pitch + Madmom + Aubio) will work for their AI Rhythm Coach project.

**Current situation:**
- Developer has an existing Flutter rhythm coach app (records drumming against metronome)
- Considering adding melody/chord recognition using this approach
- Wants quick proof-of-concept (3-5 hours) before committing to deep learning
- Will use Claude Code to write most code - developer just runs and validates

**Definition of Done:**
- Developer can run a script that analyzes audio files for chords/melody/rhythm
- Developer understands what each tool outputs and its accuracy/limitations
- Developer can answer: "Will this work for my rhythm coach project?"
- Comprehensive documentation exists outlining full learning path for future reference
- Developer knows exactly what to ask Claude Code for next steps

**ROLE:**

You are an AI coding assistant (Claude Code) specializing in rapid prototyping. You excel at:
- Writing production-ready code that works on first run
- Creating quick proof-of-concept demonstrations
- Explaining outputs and limitations clearly without deep technical detail
- Documenting future learning paths for when user wants deeper understanding
- Structuring experiments to answer "will this work?" questions efficiently

**ACTION:**

Create a rapid experimentation guide structured as follows:

### Part 1: Quick Start Experiment (3-5 Hours)

This is the immediate hands-on portion that the developer will complete NOW.

**Step 1: Environment Setup (45-60 minutes)**

Provide exact commands for each OS with minimal explanation:

**Goal:** Get Python environment with all tools working

**For Windows:**
```bash
# Python 3.10 recommended (check: python --version)
python -m venv venv
venv\Scripts\activate
pip install basic-pitch madmom aubio librosa soundfile matplotlib numpy scipy
pip install tensorflow  # For Basic Pitch
python -c "import basic_pitch, madmom, aubio; print('✓ All tools installed')"
```

**For Mac:**
```bash
# Install Homebrew if needed: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install portaudio
python3 -m venv venv
source venv/bin/activate
pip install basic-pitch madmom aubio librosa soundfile matplotlib numpy scipy
pip install tensorflow
python -c "import basic_pitch, madmom, aubio; print('✓ All tools installed')"
```

**For Linux:**
```bash
sudo apt-get update
sudo apt-get install -y portaudio19-dev python3-venv
python3 -m venv venv
source venv/bin/activate
pip install basic-pitch madmom aubio librosa soundfile matplotlib numpy scipy
pip install tensorflow
python -c "import basic_pitch, madmom, aubio; print('✓ All tools installed')"
```

**Common issues:**
- If TensorFlow fails: Try `pip install tensorflow-cpu` (smaller, CPU-only)
- If Madmom fails: May need `pip install cython` first
- If nothing works: Provide error message to Claude Code

**Step 2: Get Test Audio Files (10 minutes)**

Provide 3 simple test files:
1. **Single note**: Play A4 (440 Hz) on piano/guitar, record 5 seconds
2. **Simple chord**: Play C major chord, hold 5 seconds
3. **Beat pattern**: Metronome or hand claps, 8 beats at 120 BPM

**Quick recording command (if needed):**
```python
# quick_record.py - Claude Code provides this
import sounddevice as sd
import soundfile as sf

print("Recording 5 seconds... GO!")
audio = sd.rec(int(5 * 44100), samplerate=44100, channels=1)
sd.wait()
sf.write('test_audio.wav', audio, 44100)
print("✓ Saved as test_audio.wav")
```

Alternative: Download from freesound.org or use existing files

**Step 3: Test Basic Pitch - Melody Detection (30 minutes)**

**Claude Code provides complete script:**

```python
# test_basic_pitch.py
from basic_pitch.inference import predict
from basic_pitch import ICASSP_2022_MODEL_PATH
import pretty_midi
import matplotlib.pyplot as plt

def analyze_melody(audio_path):
    """Run Basic Pitch on audio file"""
    print(f"Analyzing melody in: {audio_path}")

    # Run inference (this downloads model on first run - may take 1-2 min)
    model_output, midi_data, note_events = predict(audio_path)

    # Save MIDI file
    midi_path = audio_path.replace('.wav', '_melody.mid')
    midi_data.write(midi_path)
    print(f"✓ MIDI saved: {midi_path}")

    # Display results
    print(f"\n✓ Detected {len(note_events)} notes:")
    for note in note_events[:10]:  # Show first 10
        pitch_name = pretty_midi.note_number_to_name(int(note['pitch']))
        print(f"  {note['start_time']:.2f}s: {pitch_name} ({note['pitch']:.1f}) - confidence: {note['confidence']:.2f}")

    # Visualize piano roll
    plt.figure(figsize=(12, 4))
    for note in note_events:
        plt.plot([note['start_time'], note['end_time']],
                [note['pitch'], note['pitch']], 'b-', linewidth=2)
    plt.xlabel('Time (seconds)')
    plt.ylabel('MIDI Pitch')
    plt.title('Detected Melody (Piano Roll)')
    plt.grid(True)
    plt.savefig(audio_path.replace('.wav', '_melody.png'))
    print(f"✓ Visualization saved: {audio_path.replace('.wav', '_melody.png')}")

    return note_events

if __name__ == "__main__":
    # Test on your audio file
    notes = analyze_melody("test_audio.wav")
    print(f"\n✓ Basic Pitch test complete!")
```

**What to look for:**
- Does it detect the correct notes?
- Compare MIDI output to what you played (open .mid file in any DAW or online viewer)
- Check confidence scores (>0.5 is good)

**Step 4: Test Madmom - Chord Detection (30 minutes)**

**Claude Code provides complete script:**

```python
# test_madmom.py
from madmom.features.chords import DeepChromaChordRecognitionProcessor
import matplotlib.pyplot as plt
import numpy as np

def analyze_chords(audio_path):
    """Run Madmom chord recognition"""
    print(f"Analyzing chords in: {audio_path}")

    # Initialize processor (downloads model on first run - may take 1-2 min)
    dcp = DeepChromaChordRecognitionProcessor()

    # Run analysis
    chords = dcp(audio_path)

    # Display results
    print(f"\n✓ Detected chord progression:")
    print(f"{'Time (s)':<10} {'Chord':<10}")
    print("-" * 20)
    for i, (time, chord) in enumerate(chords):
        print(f"{time:<10.2f} {chord:<10}")
        if i >= 20:  # Show first 20 changes
            print(f"... ({len(chords)} total chord changes)")
            break

    # Visualize chord timeline
    plt.figure(figsize=(12, 4))
    times = [c[0] for c in chords]
    chord_labels = [c[1] for c in chords]

    # Create color-coded timeline
    unique_chords = list(set(chord_labels))
    colors = plt.cm.tab20(np.linspace(0, 1, len(unique_chords)))
    chord_colors = {chord: colors[i] for i, chord in enumerate(unique_chords)}

    for i in range(len(chords) - 1):
        plt.axvspan(chords[i][0], chords[i+1][0],
                   color=chord_colors[chords[i][1]], alpha=0.5)
        plt.text((chords[i][0] + chords[i+1][0])/2, 0.5, chords[i][1],
                ha='center', va='center', fontsize=10)

    plt.xlabel('Time (seconds)')
    plt.title('Detected Chord Progression')
    plt.ylim(0, 1)
    plt.yticks([])
    plt.savefig(audio_path.replace('.wav', '_chords.png'))
    print(f"✓ Visualization saved: {audio_path.replace('.wav', '_chords.png')}")

    return chords

if __name__ == "__main__":
    chords = analyze_chords("test_audio.wav")
    print(f"\n✓ Madmom test complete!")
```

**What to look for:**
- Does it detect the correct chords?
- How stable is it (does it jump between chords rapidly or hold steady)?
- Check the 25-chord vocabulary: C, Cm, C7, Cmaj7, etc.

**Step 5: Test Aubio - Beat/Tempo Detection (30 minutes)**

**Claude Code provides complete script:**

```python
# test_aubio.py
from aubio import source, tempo
import numpy as np
import matplotlib.pyplot as plt
import librosa
import librosa.display

def analyze_rhythm(audio_path):
    """Run Aubio beat detection"""
    print(f"Analyzing rhythm in: {audio_path}")

    # Load audio
    y, sr = librosa.load(audio_path, sr=44100)

    # Setup aubio
    win_s = 1024  # FFT window size
    hop_s = 512   # Hop size

    samplerate = 44100
    s = source(audio_path, samplerate, hop_s)
    samplerate = s.samplerate

    o = tempo("default", win_s, hop_s, samplerate)

    # Detect beats
    beats = []
    total_frames = 0

    while True:
        samples, read = s()
        is_beat = o(samples)
        if is_beat:
            beat_time = o.get_last_s()
            beats.append(beat_time)
        total_frames += read
        if read < hop_s:
            break

    # Calculate tempo
    if len(beats) > 1:
        intervals = np.diff(beats)
        avg_interval = np.mean(intervals)
        bpm = 60 / avg_interval
    else:
        bpm = 0

    # Display results
    print(f"\n✓ Detected tempo: {bpm:.1f} BPM")
    print(f"✓ Detected {len(beats)} beats:")
    for i, beat_time in enumerate(beats[:20]):
        print(f"  Beat {i+1}: {beat_time:.2f}s")
    if len(beats) > 20:
        print(f"  ... ({len(beats)} total beats)")

    # Visualize beats on waveform
    plt.figure(figsize=(12, 4))
    librosa.display.waveshow(y, sr=sr, alpha=0.6)
    for beat in beats:
        plt.axvline(x=beat, color='r', linestyle='--', alpha=0.7)
    plt.xlabel('Time (seconds)')
    plt.ylabel('Amplitude')
    plt.title(f'Detected Beats (Tempo: {bpm:.1f} BPM)')
    plt.savefig(audio_path.replace('.wav', '_beats.png'))
    print(f"✓ Visualization saved: {audio_path.replace('.wav', '_beats.png')}")

    return beats, bpm

if __name__ == "__main__":
    beats, bpm = analyze_rhythm("test_audio.wav")
    print(f"\n✓ Aubio test complete!")
```

**What to look for:**
- Is the detected BPM accurate? (Compare to known tempo or metronome)
- Are beats aligned with actual beats in the audio?
- Does it lock on quickly (within 2-4 bars)?

**Step 6: Integrated Analysis (45 minutes)**

**Claude Code provides complete integrated script:**

```python
# analyze_music.py - Complete integration
from basic_pitch.inference import predict
from madmom.features.chords import DeepChromaChordRecognitionProcessor
from aubio import source, tempo
import librosa
import numpy as np
import json
from dataclasses import dataclass, asdict
from typing import List, Dict
import sys

@dataclass
class MusicAnalysis:
    """Complete music analysis result"""
    filepath: str
    duration: float

    # Rhythm
    tempo_bpm: float
    beats: List[float]

    # Chords
    chords: List[Dict]  # [{"time": 0.0, "chord": "C"}]

    # Melody
    notes: List[Dict]  # [{"start": 0.0, "end": 1.0, "pitch": 60, "name": "C4"}]

def analyze_music_complete(audio_path):
    """Run complete music analysis pipeline"""
    print(f"\n{'='*60}")
    print(f"ANALYZING: {audio_path}")
    print(f"{'='*60}\n")

    # Get duration
    y, sr = librosa.load(audio_path)
    duration = librosa.get_duration(y=y, sr=sr)

    # 1. RHYTHM ANALYSIS
    print("1/3 Analyzing rhythm (Aubio)...")
    win_s, hop_s = 1024, 512
    s = source(audio_path, 44100, hop_s)
    o = tempo("default", win_s, hop_s, 44100)

    beats = []
    while True:
        samples, read = s()
        if o(samples):
            beats.append(o.get_last_s())
        if read < hop_s:
            break

    if len(beats) > 1:
        bpm = 60 / np.mean(np.diff(beats))
    else:
        bpm = 0.0

    print(f"   ✓ Tempo: {bpm:.1f} BPM")
    print(f"   ✓ Beats: {len(beats)} detected")

    # 2. CHORD ANALYSIS
    print("\n2/3 Analyzing chords (Madmom)...")
    dcp = DeepChromaChordRecognitionProcessor()
    chord_data = dcp(audio_path)

    chords = [{"time": float(t), "chord": c} for t, c in chord_data]
    unique_chords = set(c["chord"] for c in chords)

    print(f"   ✓ Chord changes: {len(chords)}")
    print(f"   ✓ Unique chords: {len(unique_chords)} ({', '.join(sorted(unique_chords)[:5])}...)")

    # 3. MELODY ANALYSIS
    print("\n3/3 Analyzing melody (Basic Pitch)...")
    model_output, midi_data, note_events = predict(audio_path)

    import pretty_midi
    notes = []
    for note in note_events:
        notes.append({
            "start": float(note["start_time"]),
            "end": float(note["end_time"]),
            "pitch": int(note["pitch"]),
            "name": pretty_midi.note_number_to_name(int(note["pitch"])),
            "confidence": float(note["confidence"])
        })

    print(f"   ✓ Notes detected: {len(notes)}")

    # Create result object
    result = MusicAnalysis(
        filepath=audio_path,
        duration=duration,
        tempo_bpm=bpm,
        beats=beats,
        chords=chords,
        notes=notes
    )

    # Save JSON
    output_path = audio_path.replace('.wav', '_analysis.json')
    with open(output_path, 'w') as f:
        json.dump(asdict(result), f, indent=2)

    print(f"\n{'='*60}")
    print(f"✓ ANALYSIS COMPLETE")
    print(f"{'='*60}")
    print(f"\nResults saved to: {output_path}")

    # Print summary
    print(f"\n📊 SUMMARY:")
    print(f"   Duration: {duration:.1f}s")
    print(f"   Tempo: {bpm:.1f} BPM")
    print(f"   Beats: {len(beats)}")
    print(f"   Chords: {len(chords)} changes, {len(unique_chords)} unique")
    print(f"   Notes: {len(notes)} detected")

    return result

if __name__ == "__main__":
    if len(sys.argv) > 1:
        audio_file = sys.argv[1]
    else:
        audio_file = "test_audio.wav"

    result = analyze_music_complete(audio_file)
```

**Run it:**
```bash
python analyze_music.py your_audio_file.wav
```

**What to verify:**
- All three components run without errors
- Output JSON contains all data
- Results make sense for your audio

**Step 7: Evaluate for Rhythm Coach Project (30 minutes)**

**Assessment Questions:**

Answer these based on your tests:

1. **Rhythm Detection Quality:**
   - Does Aubio accurately detect beats in your drum recordings?
   - Is the BPM detection accurate enough for your metronome comparison?
   - How quickly does it lock onto the beat? (Important for real-time feedback)

2. **Melody/Chord Relevance:**
   - Does your rhythm coach project need melody detection? (Drums are typically non-melodic)
   - Would chord recognition help? (E.g., practicing drums to chord progressions)
   - Or is rhythm detection (Aubio) sufficient for your use case?

3. **Performance:**
   - How long does analysis take on a 60-second recording? (Your session length)
   - Is this fast enough for your workflow? (Immediate vs batch processing)

4. **Integration with Flutter:**
   - You'll need to call Python scripts from Flutter (using `Process` or REST API)
   - Or port algorithms to Dart (more complex)
   - Which approach feels viable?

5. **Accuracy Requirements:**
   - What accuracy do you need? (80%? 90%? 95%?)
   - Test on actual drum recordings from your app
   - Compare detected beats to metronome clicks

**Decision Framework:**

**✅ PROCEED if:**
- Aubio beat detection works well on your drum recordings (>85% accuracy)
- Processing time acceptable (<30 seconds for 60-second recording)
- You have a clear integration path (Python backend or Dart port)

**⚠️ RECONSIDER if:**
- Beat detection inaccurate on drums (<70% accuracy)
- You need melody/chords but Basic Pitch/Madmom don't work on your audio
- Processing too slow for your UX requirements

**🔄 ALTERNATIVE if:**
- Use only Aubio (rhythm) and skip melody/chords
- Try simpler onset detection (just hit detection, not beat tracking)
- Use your existing FFT-based rhythm analyzer and skip ML entirely

### Part 2: Full Learning Roadmap Documentation (For Future Reference)

**Claude Code creates this as a separate reference document** outlining the complete curriculum discussed earlier. This is NOT completed now, but documented for when the developer decides to go deeper.

**Structure:**

```markdown
# AI Music Recognition - Complete Learning Roadmap

## Phase 1: Quick Experiment (COMPLETED) ✓
[3-5 hours - what you just did]
- Environment setup
- Test each tool individually
- Integrated analysis script
- Viability assessment for rhythm coach project

## Phase 2: Audio Fundamentals (8-10 hours)
**When to do this:** If you want to understand WHY the tools work

**Learning Objectives:**
- Understand digital audio (sample rate, bit depth)
- Visualize waveforms and spectrograms
- Grasp FFT and frequency analysis
- Connect audio features to musical concepts

**Exercises:**
1. Audio loading and visualization
2. Frequency spectrum analysis
3. Spectrogram creation and interpretation
4. Feature extraction (zero-crossing, spectral centroid, etc.)

**Deliverable:** Jupyter notebook with visualizations

**Ask Claude Code:** "Walk me through Phase 2: Audio Fundamentals"

## Phase 3: Deep Dive - Tool Internals (12-15 hours)
**When to do this:** If you need to customize or troubleshoot tools

**Learning Objectives:**
- Understand Basic Pitch architecture
- Understand Madmom's Deep Chroma Network
- Understand Aubio's beat tracking algorithm
- Know when each tool succeeds/fails

**Exercises:**
1. Basic Pitch: Model architecture, training data, limitations
2. Madmom: Chord vocabulary, chromagram features, confidence scores
3. Aubio: Onset detection, tempo tracking, parameter tuning
4. Comparative testing on diverse audio

**Deliverable:** Test suite with 20+ audio samples

**Ask Claude Code:** "Walk me through Phase 3: Tool Deep Dive"

## Phase 4: Dataset Creation & Fine-Tuning (8-10 hours)
**When to do this:** If pretrained models don't work well on your specific audio

**Learning Objectives:**
- Record and annotate training data
- Apply data augmentation
- Fine-tune Madmom chord model
- Evaluate model improvements

**Exercises:**
1. Recording workflow (10-20 samples)
2. Annotation tool creation
3. Data augmentation (pitch shift, time stretch, noise)
4. Fine-tuning pipeline
5. Validation and accuracy measurement

**Deliverable:** Fine-tuned model with improved accuracy on your domain

**Ask Claude Code:** "Walk me through Phase 4: Fine-Tuning"

## Phase 5: Real-Time Processing (10-12 hours)
**When to do this:** If you need live audio analysis (not batch)

**Learning Objectives:**
- Implement streaming audio input
- Optimize for low latency (<100ms)
- Handle audio device configuration
- Build real-time visualization

**Exercises:**
1. PyAudio streaming setup
2. Buffer management (circular buffer, windowing)
3. Latency benchmarking and optimization
4. Live visualization dashboard
5. GPU acceleration

**Deliverable:** Real-time demo (play instrument → see analysis live)

**Ask Claude Code:** "Walk me through Phase 5: Real-Time Processing"

## Phase 6: Production Integration (8-10 hours)
**When to do this:** Ready to integrate into your Flutter app

**Learning Objectives:**
- Create Python microservice or CLI
- Call from Flutter using Process or HTTP
- Handle errors and edge cases
- Deploy and package

**Exercises:**
1. Flask/FastAPI REST API
2. Flutter integration (http package or Process.run)
3. Error handling and validation
4. Batch processing mode
5. Packaging (Docker or standalone executable)

**Deliverable:** Production-ready service callable from Flutter

**Ask Claude Code:** "Walk me through Phase 6: Flutter Integration"

## Phase 7: Optimization & Polish (6-8 hours)
**When to do this:** After integration, before launch

**Learning Objectives:**
- Improve accuracy on your specific audio
- Reduce latency
- Handle edge cases
- Add user-friendly error messages

**Exercises:**
1. Accuracy benchmarking on real user data
2. Performance profiling and optimization
3. Edge case handling (silence, noise, short clips)
4. Unit and integration testing
5. User documentation

**Deliverable:** Production-ready, tested system

**Ask Claude Code:** "Walk me through Phase 7: Optimization"

---

## Quick Reference: What to Ask Claude Code

**After Quick Experiment:**
- "The beat detection is inaccurate on my drums. How do I tune Aubio parameters?"
- "How do I integrate this Python script with my Flutter app?"
- "Basic Pitch detected too many false notes. How do I filter results?"
- "I want to try a different chord recognition tool. What are alternatives to Madmom?"

**When Ready for Next Phase:**
- "I'm ready for Phase 3. Walk me through tool internals."
- "Show me how to fine-tune Madmom on my drum recordings."
- "I need real-time analysis. Guide me through Phase 5."
- "Help me build a REST API for Phase 6 Flutter integration."

**Troubleshooting:**
- "Aubio isn't detecting beats on [type of audio]. What parameters should I adjust?"
- "Processing takes 2 minutes for a 60-second file. How do I optimize?"
- "Installation failed with [error message]. How do I fix this?"
- "The tools work individually but fail when integrated. Help debug."

**Advanced:**
- "Can I run this on mobile device (Android)? What's the process?"
- "How do I export analysis results to MIDI/MusicXML?"
- "I want to add confidence scores to filter unreliable results."
- "How do I handle tempo changes within a single recording?"
```

**FORMAT:**

The output should be TWO documents:

**Document 1: Quick Experiment Guide** (`quick_start_experiment.md`)
- Steps 1-7 from Part 1 (the immediate 3-5 hour hands-on)
- Copy-paste ready code
- Minimal explanation (just enough to understand outputs)
- Assessment framework at the end

**Document 2: Full Learning Roadmap** (`complete_roadmap.md`)
- Structured outline of all 7 phases
- Time estimates for each phase
- Learning objectives and deliverables
- "Ask Claude Code" prompts for each phase
- No detailed content (just structure for future reference)

**Code blocks must:**
- Be complete, production-ready scripts (not snippets)
- Include all imports and error handling
- Work on first run after environment setup
- Have clear output messages showing progress

**Explanations must:**
- Focus on "what does this output mean?" not "how does it work?"
- Relate to rhythm coach project specifically
- Include assessment criteria (good/bad results)

**TARGET AUDIENCE:**

Developer who:
- Wants to validate approach quickly (3-5 hours)
- Will ask Claude Code for help at each step
- Needs to decide: proceed, reconsider, or try alternatives
- Wants documentation of full path for future deep dive
- Is comfortable running Python scripts but not writing them from scratch

**CONSTRAINTS:**

**Do not include:**
- Deep technical explanations (save for Phase 2-7)
- Manual model training (use pretrained only)
- Advanced ML concepts (backprop, gradient descent, etc.)
- Multiple approaches/alternatives (one clear path)

**Do include:**
- Exact commands for each OS
- Complete runnable scripts
- Visual outputs (plots saved as PNG)
- Clear success/failure criteria
- Structured roadmap for future reference

**VALIDATION CRITERIA:**

Quick Experiment succeeds if:
- Developer completes Steps 1-7 in 3-5 hours
- All three tools run successfully on test audio
- Developer can answer: "Will this work for my project?"
- Complete roadmap document exists for future phases
- Developer knows exactly what to ask Claude Code next

Full Roadmap succeeds if:
- All 7 phases clearly outlined with time estimates
- Each phase has clear entry point ("Ask Claude Code: ...")
- Logical progression from fundamentals to production
- Developer can return in 1 month and know where to continue

# AI Music Recognition - Quick Start Experiment (3-5 Hours)

**Goal**: Evaluate if Basic Pitch + Madmom + Aubio will work for your rhythm coach project

---

## Step 1: Environment Setup (45-60 minutes)

### Windows

```bash
# Check Python version (3.8-3.10 recommended)
python --version

# Create virtual environment
python -m venv venv
venv\Scripts\activate

# Install dependencies
pip install basic-pitch madmom aubio librosa soundfile matplotlib numpy scipy
pip install tensorflow

# Verify installation
python -c "import basic_pitch, madmom, aubio; print('✓ All tools installed')"
```

### Mac

```bash
# Install Homebrew (if needed)
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install audio dependencies
brew install portaudio

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install basic-pitch madmom aubio librosa soundfile matplotlib numpy scipy
pip install tensorflow

# Verify installation
python -c "import basic_pitch, madmom, aubio; print('✓ All tools installed')"
```

### Linux

```bash
# Install system dependencies
sudo apt-get update
sudo apt-get install -y portaudio19-dev python3-venv

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install basic-pitch madmom aubio librosa soundfile matplotlib numpy scipy
pip install tensorflow

# Verify installation
python -c "import basic_pitch, madmom, aubio; print('✓ All tools installed')"
```

### Common Installation Issues

- **TensorFlow fails**: Try `pip install tensorflow-cpu` (smaller, CPU-only version)
- **Madmom fails**: May need `pip install cython` first
- **General errors**: Copy the full error message and ask Claude Code for help

---

## Step 2: Get Test Audio Files (10 minutes)

You need 3 simple test files:

1. **Single note**: Play A4 (440 Hz) on piano/guitar, record 5 seconds
2. **Simple chord**: Play C major chord, hold 5 seconds
3. **Beat pattern**: Metronome or hand claps, 8 beats at 120 BPM

### Quick Recording Script (Optional)

```python
# quick_record.py
import sounddevice as sd
import soundfile as sf

print("Recording 5 seconds... GO!")
audio = sd.rec(int(5 * 44100), samplerate=44100, channels=1)
sd.wait()
sf.write('test_audio.wav', audio, 44100)
print("✓ Saved as test_audio.wav")
```

**Alternative**: Download test audio from freesound.org or use existing audio files.

---

## Step 3: Test Basic Pitch - Melody Detection (30 minutes)

Create this file:

```python
# test_basic_pitch.py
from basic_pitch.inference import predict
from basic_pitch import ICASSP_2022_MODEL_PATH
import pretty_midi
import matplotlib.pyplot as plt

def analyze_melody(audio_path):
    """Run Basic Pitch on audio file"""
    print(f"Analyzing melody in: {audio_path}")

    # Run inference (downloads model on first run - may take 1-2 min)
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

**Run it:**
```bash
python test_basic_pitch.py
```

**What to look for:**
- Does it detect the correct notes?
- Open the .mid file in a DAW or online MIDI viewer to compare
- Check confidence scores (>0.5 is good, >0.7 is very confident)

---

## Step 4: Test Madmom - Chord Detection (30 minutes)

Create this file:

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

**Run it:**
```bash
python test_madmom.py
```

**What to look for:**
- Does it detect the correct chords?
- Is it stable (holds steady) or jumps between chords rapidly?
- Madmom recognizes 25 chord types: C, Cm, C7, Cmaj7, Cdim, Caug, etc.

---

## Step 5: Test Aubio - Beat/Tempo Detection (30 minutes)

Create this file:

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

**Run it:**
```bash
python test_aubio.py
```

**What to look for:**
- Is the detected BPM accurate? (Compare to known tempo or metronome setting)
- Are beats aligned with actual beats in the audio?
- Does it lock on quickly (within 2-4 bars)?

---

## Step 6: Integrated Analysis (45 minutes)

Create the complete integration:

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
- Output JSON contains all data (beats, chords, notes)
- Results make sense for your audio
- Check the generated `_analysis.json` file

---

## Step 7: Evaluate for Rhythm Coach Project (30 minutes)

### Assessment Questions

Answer these based on your test results:

#### 1. Rhythm Detection Quality
- ✓ Does Aubio accurately detect beats in your drum recordings?
- ✓ Is the BPM detection accurate enough for metronome comparison?
- ✓ How quickly does it lock onto the beat? (Important for real-time feedback)

#### 2. Melody/Chord Relevance
- Does your rhythm coach project need melody detection? (Drums are typically non-melodic)
- Would chord recognition help? (E.g., practicing drums to chord progressions)
- Or is rhythm detection (Aubio) sufficient for your use case?

#### 3. Performance
- How long does analysis take on a 60-second recording? (Your session length)
- Is this fast enough for your workflow? (Immediate vs batch processing)

#### 4. Integration with Flutter
- You'll need to call Python scripts from Flutter (using `Process` or REST API)
- Or port algorithms to Dart (more complex)
- Which approach feels viable?

#### 5. Accuracy Requirements
- What accuracy do you need? (80%? 90%? 95%?)
- Test on actual drum recordings from your app
- Compare detected beats to metronome clicks

### Decision Framework

**✅ PROCEED if:**
- Aubio beat detection works well on drum recordings (>85% accuracy)
- Processing time acceptable (<30 seconds for 60-second recording)
- You have a clear integration path (Python backend or Dart port)

**⚠️ RECONSIDER if:**
- Beat detection inaccurate on drums (<70% accuracy)
- You need melody/chords but Basic Pitch/Madmom don't work on your audio
- Processing too slow for your UX requirements

**🔄 ALTERNATIVE APPROACHES:**
- Use only Aubio (rhythm) and skip melody/chords
- Try simpler onset detection (just hit detection, not beat tracking)
- Use your existing FFT-based rhythm analyzer and skip ML entirely

---

## Next Steps

After completing this experiment:

1. **If successful**: Check `complete_roadmap.md` for next phases
2. **If issues**: Ask Claude Code specific questions about problems
3. **For integration**: Ask Claude Code: "Walk me through Phase 6: Flutter Integration"
4. **For deep dive**: Ask Claude Code: "I'm ready for Phase 2: Audio Fundamentals"

### Common Questions to Ask Claude Code

**Troubleshooting:**
- "Aubio isn't detecting beats on [type of audio]. What parameters should I adjust?"
- "Processing takes too long. How do I optimize?"
- "Installation failed with [error]. How do I fix this?"

**Next Steps:**
- "How do I integrate this with my Flutter app?"
- "Show me how to fine-tune on my drum recordings"
- "I need real-time analysis. What's the approach?"
- "Can I run this on Android? What's required?"

---

## Summary

You've now:
- ✓ Set up the complete Python environment
- ✓ Tested Basic Pitch (melody detection)
- ✓ Tested Madmom (chord recognition)
- ✓ Tested Aubio (beat/tempo tracking)
- ✓ Created an integrated analysis pipeline
- ✓ Evaluated viability for your rhythm coach project

**Time invested**: 3-5 hours
**Value gained**: Clear answer to "Will this approach work?"

Refer to `complete_roadmap.md` for the full 7-phase learning path when you're ready to go deeper.

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
        audio_file = "793343__sadiquecat__metronome-120-bpm.wav"

    result = analyze_music_complete(audio_file)

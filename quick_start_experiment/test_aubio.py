# test_aubio.py
from aubio import source, tempo
import numpy as np
import matplotlib.pyplot as plt
import librosa
import librosa.display

def analyze_rhythm(audio_path):
    """Run Aubio beat detection"""
    print(f"Analyzing rhythm in: {audio_path}")

    # Setup aubio - use file's native sample rate (set to 0 for auto-detect)
    win_s = 1024  # FFT window size
    hop_s = 512   # Hop size

    s = source(audio_path, 0, hop_s)  # 0 = use file's native sample rate
    samplerate = s.samplerate
    print(f"Audio sample rate: {samplerate} Hz")

    # Load audio with librosa for visualization
    y, sr = librosa.load(audio_path, sr=samplerate)

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
    print(f"\nDetected tempo: {bpm:.1f} BPM")
    print(f"Detected {len(beats)} beats:")
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
    print(f"Visualization saved: {audio_path.replace('.wav', '_beats.png')}")

    return beats, bpm

if __name__ == "__main__":
    beats, bpm = analyze_rhythm("793343__sadiquecat__metronome-120-bpm.wav")
    print(f"\nAubio test complete!")

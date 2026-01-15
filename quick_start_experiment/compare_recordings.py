#!/usr/bin/env python
"""
Compare the three test recordings to understand the false positive issue.
"""

import numpy as np
import librosa
import matplotlib.pyplot as plt

def analyze_recording(audio_path, title):
    """Quick analysis of a recording."""
    print("="*60)
    print(f"ANALYZING: {title}")
    print("="*60)

    y, sr = librosa.load(audio_path, sr=None)
    duration = len(y) / sr

    rms = np.sqrt(np.mean(y**2))
    max_amp = np.max(np.abs(y))

    print(f"File: {audio_path}")
    print(f"Duration: {duration:.2f}s")
    print(f"Sample rate: {sr} Hz")
    print(f"RMS Energy: {rms:.8f}")
    print(f"Max Amplitude: {max_amp:.8f}")
    print(f"Min threshold: 0.001")
    print(f"Would pass energy check: {'YES' if rms >= 0.001 else 'NO'}")
    print()

    # Detect onsets with new threshold (0.25)
    onset_env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=512)

    onset_frames = []
    for i in range(len(onset_env)):
        if onset_env[i] > 0.25:  # New threshold
            if i == 0 or (i > 0 and onset_env[i] > onset_env[i-1]):
                if i == len(onset_env)-1 or (i < len(onset_env)-1 and onset_env[i] >= onset_env[i+1]):
                    onset_frames.append(i)

    onset_times = librosa.frames_to_time(np.array(onset_frames), sr=sr, hop_length=512)

    print(f"Detected onsets (threshold 0.25): {len(onset_times)}")
    print(f"Max spectral flux: {np.max(onset_env):.4f}")
    print(f"Mean spectral flux: {np.mean(onset_env):.4f}")

    if len(onset_times) > 0:
        print(f"\nFirst 10 onset times:")
        for i, t in enumerate(onset_times[:10]):
            print(f"  {i+1}. {t:.3f}s")

    print()
    return y, sr, onset_times, onset_env

# Analyze all three recordings
recordings = [
    ("silence_test.wav", "Complete Silence"),
    ("sound_no_drum.wav", "Sound Without Drumming"),
    ("with_drumming.wav", "With Drumming")
]

results = []
for path, title in recordings:
    try:
        result = analyze_recording(path, title)
        results.append((title, result))
    except Exception as e:
        print(f"ERROR analyzing {path}: {e}")
        print()

# Create comparison visualization
if len(results) == 3:
    fig, axes = plt.subplots(3, 2, figsize=(16, 12))

    for i, (title, (y, sr, onset_times, onset_env)) in enumerate(results):
        # Waveform
        ax1 = axes[i, 0]
        librosa.display.waveshow(y, sr=sr, ax=ax1, alpha=0.7)
        for onset in onset_times:
            ax1.axvline(x=onset, color='red', alpha=0.5, linewidth=1)
        ax1.set_title(f'{title} - Waveform ({len(onset_times)} onsets)')
        ax1.set_xlabel('Time (s)')
        ax1.set_ylabel('Amplitude')

        # Spectral flux
        ax2 = axes[i, 1]
        times = librosa.times_like(onset_env, sr=sr, hop_length=512)
        ax2.plot(times, onset_env, alpha=0.7)
        ax2.axhline(y=0.25, color='red', linestyle='--', label='Threshold (0.25)')
        ax2.set_title(f'{title} - Spectral Flux')
        ax2.set_xlabel('Time (s)')
        ax2.set_ylabel('Onset Strength')
        ax2.legend()
        ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig('recording_comparison.png', dpi=150)
    print("Comparison visualization saved: recording_comparison.png")
    print()

print("="*60)
print("SUMMARY")
print("="*60)
print("If all three recordings show similar onset counts,")
print("the problem is likely in the app's detection logic itself,")
print("not just the thresholds.")
print("="*60)

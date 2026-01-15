#!/usr/bin/env python
"""
Analyze the new recordings with unprocessed audio source.
"""

import numpy as np
import librosa
import matplotlib.pyplot as plt
import soundfile as sf

def detailed_analysis(audio_path, title):
    """Detailed analysis with waveform visualization."""
    print("="*70)
    print(f"ANALYZING: {title}")
    print("="*70)

    y, sr = librosa.load(audio_path, sr=None)
    duration = len(y) / sr

    # Basic stats
    rms = np.sqrt(np.mean(y**2))
    max_amp = np.max(np.abs(y))
    min_amp = np.min(np.abs(y))
    mean_amp = np.mean(np.abs(y))

    print(f"File: {audio_path}")
    print(f"Duration: {duration:.2f}s")
    print(f"Sample rate: {sr} Hz")
    print(f"Total samples: {len(y)}")
    print()

    print("AMPLITUDE ANALYSIS:")
    print(f"  RMS Energy: {rms:.8f}")
    print(f"  Max Amplitude: {max_amp:.8f}")
    print(f"  Mean Amplitude: {mean_amp:.8f}")
    print(f"  Min Amplitude: {min_amp:.8f}")
    print()

    # Check against thresholds
    print("THRESHOLD CHECKS:")
    print(f"  minSignalEnergy (0.001): {'PASS' if rms >= 0.001 else 'FAIL (REJECTED)'}")
    print(f"  Is clipping (max >= 0.99): {'YES - BAD' if max_amp >= 0.99 else 'NO - GOOD'}")
    print()

    # Check if truly silent
    samples_above_0001 = np.sum(np.abs(y) > 0.0001)
    percent_above = (samples_above_0001 / len(y)) * 100
    print(f"NOISE ANALYSIS:")
    print(f"  Samples above 0.0001: {samples_above_0001} ({percent_above:.2f}%)")

    # Calculate noise floor (10th percentile)
    noise_floor = np.percentile(np.abs(y), 10)
    signal_floor = np.percentile(np.abs(y), 90)
    print(f"  Noise floor (10th percentile): {noise_floor:.8f}")
    print(f"  Signal floor (90th percentile): {signal_floor:.8f}")
    print(f"  Dynamic range: {(signal_floor/noise_floor):.2f}x")
    print()

    # Onset detection with threshold 0.25
    onset_env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=512)

    onset_frames = []
    for i in range(len(onset_env)):
        if onset_env[i] > 0.25:
            if i == 0 or (i > 0 and onset_env[i] > onset_env[i-1]):
                if i == len(onset_env)-1 or (i < len(onset_env)-1 and onset_env[i] >= onset_env[i+1]):
                    onset_frames.append(i)

    onset_times = librosa.frames_to_time(np.array(onset_frames), sr=sr, hop_length=512)

    print("ONSET DETECTION (threshold 0.25):")
    print(f"  Detected onsets: {len(onset_times)}")
    print(f"  Max spectral flux: {np.max(onset_env):.4f}")
    print(f"  Mean spectral flux: {np.mean(onset_env):.4f}")
    print(f"  Frames above threshold: {np.sum(onset_env > 0.25)}")

    if len(onset_times) > 0:
        print(f"\n  First 10 onset times:")
        for i, t in enumerate(onset_times[:10]):
            flux_val = onset_env[onset_frames[i]]
            print(f"    {i+1}. {t:.3f}s (flux: {flux_val:.3f})")

    print()

    # Verdict
    print("VERDICT:")
    if rms < 0.001:
        print("  -> Recording would be REJECTED (energy too low)")
    elif max_amp >= 0.99:
        print("  -> Recording is CLIPPING (AGC still amplifying)")
    elif len(onset_times) == 0:
        print("  -> Recording is CLEAN (no false positives)")
    elif len(onset_times) < 5:
        print("  -> Recording is MOSTLY CLEAN (few false positives)")
    else:
        print(f"  -> Recording has {len(onset_times)} DETECTIONS (investigating...)")

    print("="*70)
    print()

    return y, sr, onset_times, onset_env, rms, max_amp

# Analyze all three
recordings = [
    ("test_silence_new.wav", "Test 1: Complete Silence"),
    ("test_sound_new.wav", "Test 2: Sound Without Drumming"),
    ("test_drumming_new.wav", "Test 3: With Drumming")
]

results = []
for path, title in recordings:
    try:
        result = detailed_analysis(path, title)
        results.append((title, result))
    except Exception as e:
        print(f"ERROR analyzing {path}: {e}")
        print()

# Create visualization
if len(results) == 3:
    fig, axes = plt.subplots(3, 3, figsize=(18, 12))

    for i, (title, (y, sr, onset_times, onset_env, rms, max_amp)) in enumerate(results):
        # Column 1: Waveform (zoomed to first 2 seconds)
        ax1 = axes[i, 0]
        samples_2s = min(int(2 * sr), len(y))
        time_2s = np.linspace(0, samples_2s/sr, samples_2s)
        ax1.plot(time_2s, y[:samples_2s], linewidth=0.5, alpha=0.7)
        ax1.set_title(f'{title.split(":")[1]} - First 2s\nRMS:{rms:.4f} Max:{max_amp:.4f}')
        ax1.set_xlabel('Time (s)')
        ax1.set_ylabel('Amplitude')
        ax1.grid(True, alpha=0.3)
        ax1.set_ylim([-1.1, 1.1])

        # Column 2: Histogram
        ax2 = axes[i, 1]
        ax2.hist(np.abs(y), bins=100, alpha=0.7, edgecolor='black', range=(0, 0.1))
        ax2.axvline(x=0.0001, color='red', linestyle='--', label='Noise floor')
        ax2.axvline(x=0.001, color='blue', linestyle='--', label='Min energy')
        ax2.set_xlabel('Amplitude')
        ax2.set_ylabel('Count')
        ax2.set_title('Amplitude Distribution (0-0.1 range)')
        ax2.set_yscale('log')
        ax2.legend()
        ax2.grid(True, alpha=0.3)

        # Column 3: Spectral flux
        ax3 = axes[i, 2]
        times = librosa.times_like(onset_env, sr=sr, hop_length=512)
        ax3.plot(times, onset_env, alpha=0.7)
        ax3.axhline(y=0.25, color='red', linestyle='--', label='Threshold')
        for onset in onset_times[:10]:  # Mark first 10 onsets
            ax3.axvline(x=onset, color='green', alpha=0.3, linewidth=1)
        ax3.set_xlabel('Time (s)')
        ax3.set_ylabel('Onset Strength')
        ax3.set_title(f'Spectral Flux ({len(onset_times)} onsets)')
        ax3.legend()
        ax3.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig('new_recordings_analysis.png', dpi=150)
    print("\n" + "="*70)
    print("Visualization saved: new_recordings_analysis.png")
    print("="*70)

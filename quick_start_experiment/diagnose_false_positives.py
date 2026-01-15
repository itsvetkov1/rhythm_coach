#!/usr/bin/env python
"""
Diagnostic Script: False Positive Analysis
Analyzes a recording to understand why beats are being detected during silence.
"""

import numpy as np
import librosa
import matplotlib.pyplot as plt
from scipy import signal
import soundfile as sf

def analyze_recording(audio_path):
    """
    Comprehensive analysis of recording to diagnose false positive detections.
    """
    print("="*60)
    print("FALSE POSITIVE DIAGNOSTIC ANALYSIS")
    print("="*60)
    print(f"Analyzing: {audio_path}")
    print()

    # Load audio
    y, sr = librosa.load(audio_path, sr=None)
    duration = len(y) / sr

    print(f"Duration: {duration:.2f} seconds")
    print(f"Sample rate: {sr} Hz")
    print(f"Total samples: {len(y)}")
    print()

    # 1. Energy Analysis
    print("-"*60)
    print("1. ENERGY ANALYSIS")
    print("-"*60)

    rms = np.sqrt(np.mean(y**2))
    max_amplitude = np.max(np.abs(y))

    print(f"RMS Energy: {rms:.8f}")
    print(f"Max Amplitude: {max_amplitude:.8f}")
    print(f"Current threshold (minSignalEnergy): 0.00003")
    print(f"Energy check: {'PASS' if rms >= 0.00003 else 'FAIL'}")
    print()

    if rms < 0.00003:
        print("OK Recording would be rejected (too quiet)")
    else:
        print("X Recording passes energy check (analysis will proceed)")
    print()

    # 2. Noise Floor Analysis
    print("-"*60)
    print("2. NOISE FLOOR ANALYSIS")
    print("-"*60)

    # Calculate noise floor (RMS of quietest 10% of signal)
    sorted_abs = np.sort(np.abs(y))
    noise_floor_samples = sorted_abs[:int(len(sorted_abs) * 0.1)]
    noise_floor = np.sqrt(np.mean(noise_floor_samples**2))

    print(f"Estimated noise floor: {noise_floor:.8f}")
    print(f"Noise floor definition in code: 0.00001 (NOT USED)")
    print(f"Signal-to-Noise Ratio: {(rms/noise_floor):.2f}x")
    print()

    # 3. Onset Detection Analysis
    print("-"*60)
    print("3. ONSET DETECTION ANALYSIS")
    print("-"*60)

    # Detect onsets using librosa (similar method to app)
    # First get onset strength envelope
    onset_env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=512)

    # Find peaks above threshold (mimicking app's behavior)
    onset_frames = []
    for i in range(len(onset_env)):
        if onset_env[i] > 0.12:  # Match app's threshold
            # Check if this is a local maximum (avoid multiple detections for same onset)
            if i == 0 or (i > 0 and onset_env[i] > onset_env[i-1]):
                if i == len(onset_env)-1 or (i < len(onset_env)-1 and onset_env[i] >= onset_env[i+1]):
                    onset_frames.append(i)

    onset_times = librosa.frames_to_time(np.array(onset_frames), sr=sr, hop_length=512)

    print(f"Detected onsets: {len(onset_times)}")
    print(f"Onset threshold: 0.12 (normalized spectral flux)")
    print()

    if len(onset_times) > 0:
        print("First 20 onset times (seconds):")
        for i, t in enumerate(onset_times[:20]):
            print(f"  {i+1}. {t:.3f}s")
        if len(onset_times) > 20:
            print(f"  ... and {len(onset_times)-20} more")
    else:
        print("No onsets detected")
    print()

    # 4. Spectral Flux Analysis
    print("-"*60)
    print("4. SPECTRAL FLUX ANALYSIS")
    print("-"*60)

    # onset_env already calculated above in onset detection

    print(f"Max spectral flux: {np.max(onset_env):.4f}")
    print(f"Mean spectral flux: {np.mean(onset_env):.4f}")
    print(f"Std dev spectral flux: {np.std(onset_env):.4f}")
    print(f"Threshold: 0.12")
    print(f"Values above threshold: {np.sum(onset_env > 0.12)}")
    print()

    # 5. Recommendation
    print("="*60)
    print("DIAGNOSIS & RECOMMENDATIONS")
    print("="*60)

    if rms < 0.00001:
        print("OK Recording is truly silent (very low energy)")
        print("  The app should reject this recording.")
        print("  Recommended fix: INCREASE minSignalEnergy to 0.0001")
    elif rms < 0.0001:
        print("WARNING Recording has very low signal (noise floor level)")
        print("  Current threshold is too sensitive.")
        print("  Recommended fix: INCREASE minSignalEnergy to 0.0001")
    elif len(onset_times) > 50:
        print("ERROR Too many onsets detected (likely false positives)")
        print("  Onset detection threshold is too sensitive.")
        print("  Recommended fixes:")
        print("  1. INCREASE onsetThreshold from 0.12 to 0.20")
        print("  2. Add noise gating (filter samples below noise floor)")
        print("  3. INCREASE minSignalEnergy to 0.0001")
    else:
        print("? Recording appears normal")
        print("  Need to investigate further.")

    print("="*60)

    # 6. Visualization
    visualize_analysis(y, sr, onset_times, onset_env, audio_path, noise_floor)

def visualize_analysis(y, sr, onset_times, onset_env, audio_path, noise_floor):
    """Create visualization of the analysis."""
    fig, axes = plt.subplots(4, 1, figsize=(14, 12))

    # Plot 1: Waveform
    ax1 = axes[0]
    librosa.display.waveshow(y, sr=sr, ax=ax1, alpha=0.7)
    for onset_time in onset_times:
        ax1.axvline(x=onset_time, color='red', alpha=0.5, linewidth=1)
    ax1.axhline(y=noise_floor, color='green', linestyle='--', label=f'Noise floor: {noise_floor:.6f}')
    ax1.axhline(y=-noise_floor, color='green', linestyle='--')
    ax1.set_title('Waveform with Detected Onsets (red lines)')
    ax1.set_xlabel('Time (seconds)')
    ax1.set_ylabel('Amplitude')
    ax1.legend()
    ax1.grid(True, alpha=0.3)

    # Plot 2: Spectrogram
    ax2 = axes[1]
    D = librosa.stft(y, hop_length=512)
    S_db = librosa.amplitude_to_db(np.abs(D), ref=np.max)
    img = librosa.display.specshow(S_db, sr=sr, hop_length=512, x_axis='time', y_axis='hz', ax=ax2)
    ax2.set_title('Spectrogram (frequency content over time)')
    ax2.set_ylim([0, 5000])
    fig.colorbar(img, ax=ax2, format='%+2.0f dB')

    # Plot 3: Spectral Flux (Onset Strength)
    ax3 = axes[2]
    times = librosa.times_like(onset_env, sr=sr, hop_length=512)
    ax3.plot(times, onset_env, label='Spectral flux', alpha=0.7)
    ax3.axhline(y=0.12, color='red', linestyle='--', label='Threshold (0.12)')
    ax3.set_xlabel('Time (seconds)')
    ax3.set_ylabel('Onset Strength')
    ax3.set_title('Spectral Flux (measures of energy change - high = onset)')
    ax3.legend()
    ax3.grid(True, alpha=0.3)

    # Plot 4: Amplitude Histogram
    ax4 = axes[3]
    ax4.hist(np.abs(y), bins=100, alpha=0.7, edgecolor='black')
    ax4.axvline(x=noise_floor, color='green', linestyle='--', label=f'Noise floor: {noise_floor:.6f}')
    ax4.axvline(x=0.00003, color='red', linestyle='--', label='minSignalEnergy: 0.00003')
    ax4.axvline(x=0.0001, color='blue', linestyle='--', label='Recommended: 0.0001')
    ax4.set_xlabel('Amplitude')
    ax4.set_ylabel('Frequency')
    ax4.set_title('Amplitude Distribution (most samples should be near zero for silence)')
    ax4.set_yscale('log')
    ax4.legend()
    ax4.grid(True, alpha=0.3)

    plt.tight_layout()
    output_path = audio_path.replace('.wav', '_diagnostic.png')
    plt.savefig(output_path, dpi=150)
    print(f"\nVisualization saved: {output_path}")
    plt.close()

if __name__ == "__main__":
    analyze_recording("device_recording.wav")

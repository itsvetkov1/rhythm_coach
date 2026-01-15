#!/usr/bin/env python
"""
Analyze recordings with new onset detection algorithm.

This script compares the old (simple threshold) and new (adaptive + peak picking)
onset detection algorithms, providing detailed visualizations and statistics.

Usage:
    python analyze_new_recordings.py

Features:
- Noise floor measurement from first 1 second of audio
- Adaptive threshold calculation (noiseFloor * 3.0 + 0.1, min 0.15)
- Peak picking with temporal constraints (50ms minimum separation)
- Side-by-side comparison of old vs new algorithm
- Summary statistics: false positive rate, detection accuracy
"""

import numpy as np
import librosa
import matplotlib.pyplot as plt
import soundfile as sf
from typing import List, Tuple


def measure_noise_floor(y: np.ndarray, sr: int) -> float:
    """
    Measure noise floor from first 1 second of audio.

    Args:
        y: Audio samples
        sr: Sample rate

    Returns:
        RMS energy of first 1 second (noise floor measurement)
    """
    noise_samples = min(sr, len(y))  # First 1 second
    noise_segment = y[:noise_samples]
    rms = np.sqrt(np.mean(noise_segment**2))
    return rms


def calculate_adaptive_threshold(noise_floor_rms: float,
                                  noise_floor_multiplier: float = 3.0,
                                  minimum_threshold: float = 0.15) -> float:
    """
    Calculate adaptive threshold based on noise floor.

    Args:
        noise_floor_rms: Measured RMS energy of ambient noise
        noise_floor_multiplier: Multiplier for noise floor (default 3.0)
        minimum_threshold: Absolute minimum threshold (default 0.15)

    Returns:
        Adaptive threshold value
    """
    threshold = max(noise_floor_rms * noise_floor_multiplier + 0.1, minimum_threshold)
    return threshold


def apply_high_pass_filter(y: np.ndarray, sr: int, cutoff_hz: float = 60.0) -> np.ndarray:
    """
    Apply first-order high-pass filter to remove DC offset and rumble.

    Args:
        y: Audio samples
        sr: Sample rate
        cutoff_hz: Cutoff frequency in Hz (default 60.0)

    Returns:
        Filtered audio samples
    """
    # Calculate filter coefficient
    rc = 1.0 / (2.0 * np.pi * cutoff_hz)
    dt = 1.0 / sr
    alpha = rc / (rc + dt)

    # Apply filter
    filtered = np.zeros_like(y)
    if len(y) == 0:
        return filtered

    filtered[0] = y[0]
    for i in range(1, len(y)):
        filtered[i] = alpha * (filtered[i-1] + y[i] - y[i-1])

    return filtered


def pick_peaks(onset_env: np.ndarray,
               threshold: float,
               sr: int,
               hop_length: int = 512,
               min_separation_ms: float = 50.0,
               strength_multiplier: float = 1.5) -> Tuple[List[float], List[int]]:
    """
    Pick peaks from spectral flux with temporal constraints.

    Args:
        onset_env: Spectral flux values
        threshold: Base threshold value
        sr: Sample rate
        hop_length: Hop size for frame timing
        min_separation_ms: Minimum time between peaks in milliseconds
        strength_multiplier: Peaks must be this many times above threshold

    Returns:
        Tuple of (onset_times, onset_frames)
    """
    strength_threshold = threshold * strength_multiplier
    min_frames = int((min_separation_ms / 1000.0) * sr / hop_length)

    # Find local maxima above strength threshold
    candidates = []
    for i in range(1, len(onset_env) - 1):
        if onset_env[i] >= strength_threshold:
            # Check if local maximum
            if onset_env[i] > onset_env[i-1] and onset_env[i] >= onset_env[i+1]:
                candidates.append((i, onset_env[i]))

    # Sort by strength (strongest first)
    candidates.sort(key=lambda x: x[1], reverse=True)

    # Filter by minimum separation
    selected_frames = []
    for frame, strength in candidates:
        # Check if far enough from all previously selected peaks
        too_close = False
        for selected in selected_frames:
            if abs(frame - selected) < min_frames:
                too_close = True
                break

        if not too_close:
            selected_frames.append(frame)

    # Sort chronologically
    selected_frames.sort()

    # Convert to times
    onset_times = librosa.frames_to_time(np.array(selected_frames), sr=sr, hop_length=hop_length)

    return onset_times.tolist(), selected_frames


def detect_onsets_old(y: np.ndarray, sr: int, hop_length: int = 512) -> Tuple[List[float], np.ndarray]:
    """
    Old onset detection algorithm (simple threshold 0.25).

    Returns:
        Tuple of (onset_times, onset_env)
    """
    onset_env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop_length)

    onset_frames = []
    for i in range(len(onset_env)):
        if onset_env[i] > 0.25:
            if i == 0 or (i > 0 and onset_env[i] > onset_env[i-1]):
                if i == len(onset_env)-1 or (i < len(onset_env)-1 and onset_env[i] >= onset_env[i+1]):
                    onset_frames.append(i)

    onset_times = librosa.frames_to_time(np.array(onset_frames), sr=sr, hop_length=hop_length)

    return onset_times.tolist(), onset_env


def detect_onsets_new(y: np.ndarray, sr: int, hop_length: int = 512) -> Tuple[List[float], np.ndarray, float, float]:
    """
    New onset detection algorithm with adaptive threshold and peak picking.

    Returns:
        Tuple of (onset_times, onset_env, noise_floor, adaptive_threshold)
    """
    # Step 1: Measure noise floor
    noise_floor = measure_noise_floor(y, sr)

    # Step 2: Apply high-pass filter
    y_filtered = apply_high_pass_filter(y, sr, cutoff_hz=60.0)

    # Step 3: Calculate spectral flux
    onset_env = librosa.onset.onset_strength(y=y_filtered, sr=sr, hop_length=hop_length)

    # Step 4: Calculate adaptive threshold
    adaptive_threshold = calculate_adaptive_threshold(noise_floor)

    # Step 5: Pick peaks with temporal constraints
    onset_times, onset_frames = pick_peaks(
        onset_env,
        adaptive_threshold,
        sr,
        hop_length,
        min_separation_ms=50.0,
        strength_multiplier=1.5
    )

    return onset_times, onset_env, noise_floor, adaptive_threshold


def analyze_recording(audio_path: str, title: str, expected_beats: int = None) -> dict:
    """
    Analyze a recording with both old and new algorithms.

    Args:
        audio_path: Path to WAV file
        title: Display title
        expected_beats: Expected number of drum hits (for accuracy calculation)

    Returns:
        Dictionary with analysis results
    """
    print("="*70)
    print(f"ANALYZING: {title}")
    print("="*70)

    # Load audio
    y, sr = librosa.load(audio_path, sr=None)
    duration = len(y) / sr

    # Basic stats
    rms = np.sqrt(np.mean(y**2))
    max_amp = np.max(np.abs(y))

    print(f"File: {audio_path}")
    print(f"Duration: {duration:.2f}s")
    print(f"Sample rate: {sr} Hz")
    print(f"RMS Energy: {rms:.6f}")
    print(f"Max Amplitude: {max_amp:.6f}")
    print()

    # Old algorithm
    print("OLD ALGORITHM (hardcoded threshold 0.25):")
    onset_times_old, onset_env_old = detect_onsets_old(y, sr)
    print(f"  Detected onsets: {len(onset_times_old)}")
    print(f"  Max spectral flux: {np.max(onset_env_old):.4f}")
    print(f"  Mean spectral flux: {np.mean(onset_env_old):.4f}")
    print()

    # New algorithm
    print("NEW ALGORITHM (adaptive threshold + peak picking):")
    onset_times_new, onset_env_new, noise_floor, adaptive_threshold = detect_onsets_new(y, sr)
    print(f"  Noise floor (RMS): {noise_floor:.6f}")
    print(f"  Adaptive threshold: {adaptive_threshold:.4f}")
    print(f"  Detected onsets: {len(onset_times_new)}")
    print(f"  Max spectral flux: {np.max(onset_env_new):.4f}")
    print(f"  Mean spectral flux: {np.mean(onset_env_new):.4f}")
    print()

    # Calculate statistics
    if expected_beats is not None:
        accuracy_old = min(100.0, (len(onset_times_old) / expected_beats) * 100.0) if expected_beats > 0 else 0.0
        accuracy_new = min(100.0, (len(onset_times_new) / expected_beats) * 100.0) if expected_beats > 0 else 0.0

        print("STATISTICS:")
        print(f"  Expected beats: {expected_beats}")
        print(f"  Old algorithm accuracy: {accuracy_old:.1f}%")
        print(f"  New algorithm accuracy: {accuracy_new:.1f}%")

        if expected_beats == 0:
            # This is a silence/noise test
            false_positive_old = len(onset_times_old)
            false_positive_new = len(onset_times_new)
            print(f"  Old algorithm false positives: {false_positive_old}")
            print(f"  New algorithm false positives: {false_positive_new}")
        print()
    else:
        accuracy_old = None
        accuracy_new = None

    # Verdict
    print("VERDICT:")
    if expected_beats == 0:
        if len(onset_times_old) == 0:
            print(f"  Old: [PASS] No false positives")
        else:
            print(f"  Old: [FAIL] {len(onset_times_old)} false positives detected")

        if len(onset_times_new) == 0:
            print(f"  New: [PASS] No false positives")
        else:
            print(f"  New: [FAIL] {len(onset_times_new)} false positives detected")
    elif expected_beats is not None:
        old_diff = abs(len(onset_times_old) - expected_beats)
        new_diff = abs(len(onset_times_new) - expected_beats)

        print(f"  Old: {len(onset_times_old)}/{expected_beats} detected (off by {old_diff})")
        print(f"  New: {len(onset_times_new)}/{expected_beats} detected (off by {new_diff})")

        if new_diff < old_diff:
            print(f"  Winner: NEW algorithm (improved by {old_diff - new_diff})")
        elif old_diff < new_diff:
            print(f"  Winner: OLD algorithm (better by {new_diff - old_diff})")
        else:
            print(f"  Result: TIE")

    print("="*70)
    print()

    return {
        'title': title,
        'y': y,
        'sr': sr,
        'rms': rms,
        'max_amp': max_amp,
        'onset_times_old': onset_times_old,
        'onset_env_old': onset_env_old,
        'onset_times_new': onset_times_new,
        'onset_env_new': onset_env_new,
        'noise_floor': noise_floor,
        'adaptive_threshold': adaptive_threshold,
        'expected_beats': expected_beats,
        'accuracy_old': accuracy_old,
        'accuracy_new': accuracy_new,
    }


def create_visualization(results: List[dict]):
    """Create comprehensive visualization comparing old vs new algorithms."""
    n_recordings = len(results)
    fig, axes = plt.subplots(n_recordings, 4, figsize=(24, 6*n_recordings))

    # Handle single recording case
    if n_recordings == 1:
        axes = axes.reshape(1, -1)

    for i, result in enumerate(results):
        y = result['y']
        sr = result['sr']
        title = result['title']

        # Column 1: Waveform (first 3 seconds)
        ax1 = axes[i, 0]
        samples_3s = min(int(3 * sr), len(y))
        time_3s = np.linspace(0, samples_3s/sr, samples_3s)
        ax1.plot(time_3s, y[:samples_3s], linewidth=0.5, alpha=0.7, color='steelblue')
        ax1.set_title(f'{title}\nRMS:{result["rms"]:.4f} Max:{result["max_amp"]:.4f}')
        ax1.set_xlabel('Time (s)')
        ax1.set_ylabel('Amplitude')
        ax1.grid(True, alpha=0.3)
        ax1.set_ylim([-1.1, 1.1])

        # Add noise floor indicator
        noise_line = result['noise_floor']
        ax1.axhline(y=noise_line, color='orange', linestyle='--', alpha=0.5,
                   label=f'Noise floor: {noise_line:.4f}')
        ax1.axhline(y=-noise_line, color='orange', linestyle='--', alpha=0.5)
        ax1.legend(loc='upper right', fontsize=8)

        # Column 2: Old algorithm spectral flux
        ax2 = axes[i, 1]
        times_old = librosa.times_like(result['onset_env_old'], sr=sr, hop_length=512)
        ax2.plot(times_old, result['onset_env_old'], alpha=0.7, color='red')
        ax2.axhline(y=0.25, color='darkred', linestyle='--', linewidth=2, label='Threshold: 0.25')

        # Mark detected onsets
        for onset in result['onset_times_old'][:20]:  # First 20 onsets
            ax2.axvline(x=onset, color='red', alpha=0.3, linewidth=2)

        ax2.set_xlabel('Time (s)')
        ax2.set_ylabel('Spectral Flux')
        ax2.set_title(f'OLD Algorithm: {len(result["onset_times_old"])} onsets\nHardcoded threshold: 0.25')
        ax2.legend()
        ax2.grid(True, alpha=0.3)

        # Column 3: New algorithm spectral flux
        ax3 = axes[i, 2]
        times_new = librosa.times_like(result['onset_env_new'], sr=sr, hop_length=512)
        ax3.plot(times_new, result['onset_env_new'], alpha=0.7, color='green')

        threshold = result['adaptive_threshold']
        strength_threshold = threshold * 1.5
        ax3.axhline(y=threshold, color='orange', linestyle='--', linewidth=2,
                   label=f'Adaptive threshold: {threshold:.3f}')
        ax3.axhline(y=strength_threshold, color='darkgreen', linestyle='--', linewidth=2,
                   label=f'Peak threshold: {strength_threshold:.3f}')

        # Mark detected onsets
        for onset in result['onset_times_new'][:20]:  # First 20 onsets
            ax3.axvline(x=onset, color='green', alpha=0.5, linewidth=2)

        ax3.set_xlabel('Time (s)')
        ax3.set_ylabel('Spectral Flux')
        ax3.set_title(f'NEW Algorithm: {len(result["onset_times_new"])} onsets\nNoise floor: {result["noise_floor"]:.4f}')
        ax3.legend()
        ax3.grid(True, alpha=0.3)

        # Column 4: Summary comparison
        ax4 = axes[i, 3]
        ax4.axis('off')

        summary_text = f"COMPARISON SUMMARY\n\n"
        summary_text += f"Recording: {title}\n"
        summary_text += f"Duration: {len(y)/sr:.1f}s\n\n"

        summary_text += f"NOISE METRICS:\n"
        summary_text += f"  RMS: {result['rms']:.6f}\n"
        summary_text += f"  Noise floor: {result['noise_floor']:.6f}\n"
        summary_text += f"  Max amplitude: {result['max_amp']:.3f}\n\n"

        summary_text += f"OLD ALGORITHM:\n"
        summary_text += f"  Threshold: 0.25 (fixed)\n"
        summary_text += f"  Detections: {len(result['onset_times_old'])}\n"
        if result['accuracy_old'] is not None:
            summary_text += f"  Accuracy: {result['accuracy_old']:.1f}%\n"
        summary_text += "\n"

        summary_text += f"NEW ALGORITHM:\n"
        summary_text += f"  Threshold: {result['adaptive_threshold']:.3f} (adaptive)\n"
        summary_text += f"  Peak threshold: {result['adaptive_threshold']*1.5:.3f}\n"
        summary_text += f"  Detections: {len(result['onset_times_new'])}\n"
        if result['accuracy_new'] is not None:
            summary_text += f"  Accuracy: {result['accuracy_new']:.1f}%\n"
        summary_text += "\n"

        if result['expected_beats'] is not None:
            if result['expected_beats'] == 0:
                # False positive test
                improvement = len(result['onset_times_old']) - len(result['onset_times_new'])
                summary_text += f"VERDICT:\n"
                summary_text += f"  Expected: 0 beats\n"
                summary_text += f"  Old FP: {len(result['onset_times_old'])}\n"
                summary_text += f"  New FP: {len(result['onset_times_new'])}\n"
                if improvement > 0:
                    summary_text += f"  [+] Reduced by {improvement}\n"
                elif improvement < 0:
                    summary_text += f"  [-] Increased by {-improvement}\n"
                else:
                    summary_text += f"  [=] No change\n"
            else:
                # Detection accuracy test
                old_error = abs(len(result['onset_times_old']) - result['expected_beats'])
                new_error = abs(len(result['onset_times_new']) - result['expected_beats'])
                summary_text += f"VERDICT:\n"
                summary_text += f"  Expected: {result['expected_beats']} beats\n"
                summary_text += f"  Old error: {old_error}\n"
                summary_text += f"  New error: {new_error}\n"
                if new_error < old_error:
                    summary_text += f"  [+] NEW is better\n"
                elif old_error < new_error:
                    summary_text += f"  [-] OLD is better\n"
                else:
                    summary_text += f"  [=] Tie\n"

        ax4.text(0.05, 0.95, summary_text, transform=ax4.transAxes,
                fontsize=10, verticalalignment='top', family='monospace',
                bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.3))

    plt.tight_layout()
    plt.savefig('onset_detection_comparison.png', dpi=150, bbox_inches='tight')
    print("\n" + "="*70)
    print("Visualization saved: onset_detection_comparison.png")
    print("="*70)


def main():
    """Main analysis routine."""
    print("\n" + "="*70)
    print("ONSET DETECTION ALGORITHM COMPARISON")
    print("Old (hardcoded threshold) vs New (adaptive + peak picking)")
    print("="*70 + "\n")

    # Define test recordings with expected beat counts
    # expected_beats: None = unknown, 0 = silence/noise (false positive test), N = drum recording
    recordings = [
        ("test_silence_new.wav", "Test 1: Complete Silence", 0),
        ("test_sound_new.wav", "Test 2: Background Noise", 0),
        ("test_drumming_new.wav", "Test 3: With Drumming", None),  # Unknown expected count
    ]

    results = []
    for path, title, expected_beats in recordings:
        try:
            result = analyze_recording(path, title, expected_beats)
            results.append(result)
        except FileNotFoundError:
            print(f"WARNING: File not found: {path}")
            print(f"Skipping {title}")
            print()
        except Exception as e:
            print(f"ERROR analyzing {path}: {e}")
            print()

    # Create visualization
    if len(results) > 0:
        create_visualization(results)

        # Print overall summary
        print("\n" + "="*70)
        print("OVERALL SUMMARY")
        print("="*70)

        total_fp_old = sum(len(r['onset_times_old']) for r in results if r['expected_beats'] == 0)
        total_fp_new = sum(len(r['onset_times_new']) for r in results if r['expected_beats'] == 0)

        print(f"\nFalse Positive Tests:")
        print(f"  Old algorithm: {total_fp_old} total false positives")
        print(f"  New algorithm: {total_fp_new} total false positives")
        if total_fp_old > total_fp_new:
            print(f"  [PASS] NEW algorithm reduced false positives by {total_fp_old - total_fp_new}")
        elif total_fp_new > total_fp_old:
            print(f"  [FAIL] NEW algorithm increased false positives by {total_fp_new - total_fp_old}")
        else:
            print(f"  [INFO] Both algorithms have equal false positive rates")

        accuracy_results = [r for r in results if r['expected_beats'] is not None and r['expected_beats'] > 0]
        if accuracy_results:
            avg_acc_old = np.mean([r['accuracy_old'] for r in accuracy_results])
            avg_acc_new = np.mean([r['accuracy_new'] for r in accuracy_results])
            print(f"\nDetection Accuracy Tests:")
            print(f"  Old algorithm: {avg_acc_old:.1f}% average accuracy")
            print(f"  New algorithm: {avg_acc_new:.1f}% average accuracy")

        print("\n" + "="*70)
    else:
        print("No recordings analyzed. Check that WAV files exist in current directory.")


if __name__ == '__main__':
    main()

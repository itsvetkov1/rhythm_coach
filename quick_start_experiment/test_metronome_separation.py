#!/usr/bin/env python
"""
Unit Test: Verify Metronome Separation
Tests if a recording contains only drums or also has metronome clicks.
"""

import numpy as np
import librosa
import matplotlib.pyplot as plt
from scipy import signal
from scipy.stats import pearsonr

def load_audio(audio_path, duration=30):
    """Load and trim audio to first N seconds."""
    y, sr = librosa.load(audio_path, sr=None, duration=duration)
    return y, sr

def detect_periodic_clicks(y, sr, expected_bpm=120):
    """
    Detect if there are periodic clicks at metronome frequency.

    Metronome clicks create very regular patterns in the audio.
    If we see strong periodicity at the expected BPM, metronome is present.
    """
    # Calculate onset strength (energy envelope)
    onset_env = librosa.onset.onset_strength(y=y, sr=sr)

    # Calculate tempogram (shows periodic patterns)
    tempogram = librosa.feature.tempogram(onset_envelope=onset_env, sr=sr)

    # Get the BPM that has strongest periodicity
    tempo_freqs = librosa.tempo_frequencies(len(tempogram), sr=sr)

    # Find energy at expected metronome BPM
    expected_idx = np.argmin(np.abs(tempo_freqs - expected_bpm))
    energy_at_expected_bpm = np.mean(tempogram[expected_idx, :])

    # Find overall max energy
    max_energy = np.max(np.mean(tempogram, axis=1))

    # If expected BPM has high energy relative to max, metronome likely present
    periodicity_ratio = energy_at_expected_bpm / max_energy if max_energy > 0 else 0

    return periodicity_ratio, tempo_freqs, tempogram

def detect_high_frequency_clicks(y, sr):
    """
    Metronome clicks are usually high-frequency beeps (800-2000 Hz).
    Check for consistent high-frequency energy.
    """
    # Compute spectrogram
    D = librosa.stft(y)
    magnitude = np.abs(D)

    # Get frequency bins
    freqs = librosa.fft_frequencies(sr=sr)

    # Define metronome frequency range (typically 800-2000 Hz)
    metronome_range = (freqs >= 800) & (freqs <= 2000)

    # Calculate energy in metronome frequency range
    metronome_energy = np.sum(magnitude[metronome_range, :], axis=0)

    # Calculate total energy
    total_energy = np.sum(magnitude, axis=0)

    # Ratio of metronome-band energy to total energy
    metronome_ratio = np.mean(metronome_energy / (total_energy + 1e-10))

    # Check for regular pulses in this frequency band
    # Metronome should create regular spikes
    metronome_peaks, _ = signal.find_peaks(metronome_energy,
                                           height=np.mean(metronome_energy) * 2,
                                           distance=int(sr * 0.4 / 512))  # At 120 BPM

    # Calculate regularity of peaks (should be very regular for metronome)
    if len(metronome_peaks) > 2:
        peak_intervals = np.diff(metronome_peaks)
        interval_std = np.std(peak_intervals)
        interval_mean = np.mean(peak_intervals)
        regularity = interval_std / (interval_mean + 1e-10)  # Lower = more regular
    else:
        regularity = 1.0  # No regular pattern

    return metronome_ratio, regularity, len(metronome_peaks)

def compare_with_known_metronome(test_audio_path, metronome_reference_path):
    """
    Compare test audio with a known metronome recording.
    High correlation = metronome present in test audio.
    """
    # Load both
    y_test, sr_test = librosa.load(test_audio_path, sr=22050, duration=10)
    y_ref, sr_ref = librosa.load(metronome_reference_path, sr=22050, duration=10)

    # Extract onset envelopes
    onset_test = librosa.onset.onset_strength(y=y_test, sr=sr_test)
    onset_ref = librosa.onset.onset_strength(y=y_ref, sr=sr_ref)

    # Trim to same length
    min_len = min(len(onset_test), len(onset_ref))
    onset_test = onset_test[:min_len]
    onset_ref = onset_ref[:min_len]

    # Calculate correlation
    correlation, _ = pearsonr(onset_test, onset_ref)

    return correlation

def visualize_separation_test(audio_path, y, sr, results):
    """Create visualization showing test results."""
    fig, axes = plt.subplots(3, 1, figsize=(14, 10))

    # Plot 1: Waveform
    ax1 = axes[0]
    librosa.display.waveshow(y, sr=sr, ax=ax1, alpha=0.7)
    ax1.set_title(f'Audio Waveform: {audio_path}')
    ax1.set_xlabel('Time (seconds)')
    ax1.set_ylabel('Amplitude')

    # Plot 2: Spectrogram with metronome frequency band highlighted
    ax2 = axes[1]
    D = librosa.stft(y)
    S_db = librosa.amplitude_to_db(np.abs(D), ref=np.max)
    img = librosa.display.specshow(S_db, sr=sr, x_axis='time', y_axis='hz', ax=ax2)
    ax2.axhspan(800, 2000, color='red', alpha=0.2, label='Metronome frequency range')
    ax2.set_ylim([0, 5000])
    ax2.set_title('Spectrogram (Red band = typical metronome frequencies)')
    ax2.legend()
    fig.colorbar(img, ax=ax2, format='%+2.0f dB')

    # Plot 3: Onset strength with periodicity
    ax3 = axes[2]
    onset_env = librosa.onset.onset_strength(y=y, sr=sr)
    times = librosa.times_like(onset_env, sr=sr)
    ax3.plot(times, onset_env, label='Onset Strength')
    ax3.set_xlabel('Time (seconds)')
    ax3.set_ylabel('Onset Strength')
    ax3.set_title('Onset Strength (Regular spikes = metronome present)')
    ax3.legend()
    ax3.grid(True, alpha=0.3)

    plt.tight_layout()
    output_path = audio_path.replace('.wav', '_separation_test.png')
    plt.savefig(output_path, dpi=150)
    print(f"\nVisualization saved: {output_path}")
    plt.close()

def run_separation_test(audio_path, expected_bpm=120):
    """
    Main test function to determine if metronome was successfully separated.

    Returns:
        dict: Test results with pass/fail for each metric
    """
    print("="*60)
    print("METRONOME SEPARATION TEST")
    print("="*60)
    print(f"Testing: {audio_path}")
    print(f"Expected BPM: {expected_bpm}")
    print()

    # Load audio (first 30 seconds)
    y, sr = load_audio(audio_path, duration=30)
    duration = len(y) / sr
    print(f"Audio loaded: {duration:.1f} seconds at {sr} Hz")

    # Test 1: Periodic click detection
    print("\n" + "-"*60)
    print("TEST 1: Periodic Pattern Detection")
    print("-"*60)
    periodicity_ratio, tempo_freqs, tempogram = detect_periodic_clicks(y, sr, expected_bpm)
    print(f"Periodicity ratio at {expected_bpm} BPM: {periodicity_ratio:.3f}")
    print(f"Threshold for metronome detection: 0.70")

    if periodicity_ratio > 0.70:
        print("RESULT: STRONG periodic pattern detected -> Metronome likely PRESENT")
        test1_pass = False
    else:
        print("RESULT: Weak periodic pattern -> Metronome likely ABSENT")
        test1_pass = True

    # Test 2: High-frequency click detection
    print("\n" + "-"*60)
    print("TEST 2: High-Frequency Click Detection")
    print("-"*60)
    metronome_ratio, regularity, num_peaks = detect_high_frequency_clicks(y, sr)
    print(f"High-frequency energy ratio: {metronome_ratio:.3f}")
    print(f"Peak regularity (lower = more regular): {regularity:.3f}")
    print(f"Number of regular peaks detected: {num_peaks}")
    print(f"Thresholds: ratio > 0.15 AND regularity < 0.3 = metronome present")

    if metronome_ratio > 0.15 and regularity < 0.3:
        print("RESULT: Regular high-frequency clicks detected -> Metronome likely PRESENT")
        test2_pass = False
    else:
        print("RESULT: No regular high-frequency pattern -> Metronome likely ABSENT")
        test2_pass = True

    # Test 3: Compare with known metronome
    print("\n" + "-"*60)
    print("TEST 3: Comparison with Known Metronome")
    print("-"*60)

    metronome_ref = "793343__sadiquecat__metronome-120-bpm.wav"
    try:
        correlation = compare_with_known_metronome(audio_path, metronome_ref)
        print(f"Correlation with pure metronome: {correlation:.3f}")
        print(f"Threshold: correlation > 0.50 = metronome present")

        if correlation > 0.50:
            print("RESULT: High correlation with metronome -> Metronome likely PRESENT")
            test3_pass = False
        else:
            print("RESULT: Low correlation with metronome -> Metronome likely ABSENT")
            test3_pass = True
    except Exception as e:
        print(f"Could not run comparison test: {e}")
        test3_pass = None

    # Overall result
    print("\n" + "="*60)
    print("FINAL VERDICT")
    print("="*60)

    tests_passed = sum([test1_pass, test2_pass, test3_pass if test3_pass is not None else True])
    tests_total = 3 if test3_pass is not None else 2

    if tests_passed == tests_total:
        verdict = "PASSED - Metronome successfully separated!"
        success = True
        print(f"All {tests_total} tests passed.")
        print("Your recording contains ONLY DRUMS (no metronome).")
        print("Great job! This is ideal for rhythm analysis.")
    elif tests_passed >= tests_total - 1:
        verdict = "PARTIAL - Metronome mostly separated"
        success = True
        print(f"{tests_passed}/{tests_total} tests passed.")
        print("Metronome separation is good but not perfect.")
        print("Should work fine for analysis.")
    else:
        verdict = "FAILED - Metronome still in recording"
        success = False
        print(f"Only {tests_passed}/{tests_total} tests passed.")
        print("Your recording still contains metronome clicks.")
        print("This will interfere with drum hit detection.")

    print("="*60)

    # Create visualization
    results = {
        'periodicity_ratio': periodicity_ratio,
        'metronome_ratio': metronome_ratio,
        'regularity': regularity,
        'num_peaks': num_peaks,
        'correlation': correlation if test3_pass is not None else None,
        'test1_pass': test1_pass,
        'test2_pass': test2_pass,
        'test3_pass': test3_pass,
        'overall_pass': success,
        'verdict': verdict
    }

    visualize_separation_test(audio_path, y, sr, results)

    return results

if __name__ == "__main__":
    # Test the recording
    results = run_separation_test("test1.wav", expected_bpm=120)

    # Print summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    print(f"Verdict: {results['verdict']}")
    print(f"Overall: {'PASSED' if results['overall_pass'] else 'FAILED'}")
    print("\nRecommendation:")
    if results['overall_pass']:
        print("-> Proceed with rhythm analysis using this recording!")
    else:
        print("-> Re-record with metronome ONLY in headphones (not in audio)")
        print("-> Make sure recording only captures drum sounds")
    print("="*60)

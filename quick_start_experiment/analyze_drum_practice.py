#!/usr/bin/env python
"""
Drum Practice Analyzer
Analyzes a recording of drumming with metronome and provides timing feedback.
"""

from aubio import source, onset, tempo
import numpy as np
import matplotlib.pyplot as plt
import librosa
import librosa.display
import soundfile as sf
from collections import defaultdict

def detect_onsets(audio_path, sensitivity='default'):
    """
    Detect all onsets (hits) in the audio file.

    Onsets are the beginnings of notes/hits - when the drum is struck.
    Think of it as detecting every time you hit the drum.

    Args:
        audio_path: Path to the audio file
        sensitivity: 'high', 'default', or 'low' - how sensitive to quiet hits

    Returns:
        List of onset times in seconds
    """
    print(f"Detecting drum hits in: {audio_path}")

    # Setup aubio onset detector
    win_s = 512      # Window size - how much audio to analyze at once
    hop_s = 256      # Hop size - how often to check for onsets

    s = source(audio_path, 0, hop_s)  # 0 = auto-detect sample rate
    samplerate = s.samplerate
    print(f"Audio sample rate: {samplerate} Hz")

    # Create onset detector
    # Methods: 'default', 'energy', 'hfc', 'complex', 'phase', 'specdiff', 'kl', 'mkl'
    # 'default' is good for drums
    o = onset("default", win_s, hop_s, samplerate)

    # Adjust sensitivity
    if sensitivity == 'high':
        o.set_threshold(0.3)  # Lower threshold = more sensitive
    elif sensitivity == 'low':
        o.set_threshold(0.7)  # Higher threshold = less sensitive
    else:
        o.set_threshold(0.5)  # Default

    onsets = []
    total_frames = 0

    # Read through the audio and detect onsets
    while True:
        samples, read = s()
        if o(samples):
            onset_time = o.get_last_s()
            onsets.append(onset_time)
        total_frames += read
        if read < hop_s:
            break

    print(f"Detected {len(onsets)} hits total")
    return np.array(onsets)

def detect_tempo(audio_path):
    """
    Detect the tempo (BPM) of the audio.
    This helps us figure out where the metronome beats SHOULD be.

    Returns:
        tempo in BPM, list of beat times
    """
    print(f"\nDetecting tempo...")

    win_s = 1024
    hop_s = 512

    s = source(audio_path, 0, hop_s)
    o = tempo("default", win_s, hop_s, s.samplerate)

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
        bpm = 120  # Default fallback

    print(f"Detected tempo: {bpm:.1f} BPM")
    print(f"Detected {len(beats)} beats")

    return bpm, np.array(beats)

def generate_expected_beats(bpm, duration, start_offset=0):
    """
    Generate expected metronome beat times based on BPM.

    This creates a list of times when the metronome SHOULD click.

    Args:
        bpm: Beats per minute
        duration: Total duration in seconds
        start_offset: When the first beat occurs (in seconds)

    Returns:
        Array of expected beat times
    """
    beat_interval = 60.0 / bpm  # Time between beats in seconds
    num_beats = int(duration / beat_interval)
    expected_beats = np.array([start_offset + i * beat_interval for i in range(num_beats)])
    return expected_beats

def match_onsets_to_beats(onsets, expected_beats, tolerance=0.15):
    """
    Match detected hits to expected metronome beats.

    For each expected beat, find the closest drum hit (if any).
    Calculate how early or late each hit was.

    Args:
        onsets: Detected drum hit times
        expected_beats: Expected metronome beat times
        tolerance: Maximum time difference to consider a match (seconds)

    Returns:
        List of timing errors for each beat (in milliseconds)
        positive = late, negative = early
    """
    print(f"\nMatching drum hits to expected beats...")
    print(f"Tolerance: {tolerance*1000:.0f}ms")

    timing_errors = []
    matched_onsets = []

    for beat_time in expected_beats:
        # Find closest onset to this expected beat
        if len(onsets) == 0:
            continue

        time_diffs = np.abs(onsets - beat_time)
        closest_idx = np.argmin(time_diffs)
        closest_time = onsets[closest_idx]
        time_diff = closest_time - beat_time

        # Only count it if within tolerance
        if abs(time_diff) <= tolerance:
            timing_errors.append(time_diff * 1000)  # Convert to milliseconds
            matched_onsets.append(closest_time)

    return np.array(timing_errors), np.array(matched_onsets)

def analyze_practice_session(audio_path, known_bpm=None, trim_duration=None):
    """
    Complete analysis of a drum practice session.

    Args:
        audio_path: Path to the audio file
        known_bpm: If you know the BPM, provide it. Otherwise we'll detect it.
        trim_duration: If provided, only analyze the first N seconds

    Returns:
        Dictionary with analysis results
    """
    print("="*60)
    print("DRUM PRACTICE ANALYSIS")
    print("="*60)

    # Load audio to get duration
    y, sr = librosa.load(audio_path, sr=None)
    full_duration = librosa.get_duration(y=y, sr=sr)
    print(f"Original audio duration: {full_duration:.1f} seconds")

    # Trim if requested
    if trim_duration is not None and trim_duration < full_duration:
        num_samples = int(trim_duration * sr)
        y = y[:num_samples]
        print(f"Trimmed to first {trim_duration} seconds")

        # Save trimmed audio for analysis
        trimmed_path = audio_path.replace('.wav', '_trimmed.wav')
        sf.write(trimmed_path, y, sr)
        print(f"Trimmed audio saved as: {trimmed_path}")

        # Use trimmed file for aubio processing
        audio_path_for_analysis = trimmed_path
    else:
        audio_path_for_analysis = audio_path

    duration = librosa.get_duration(y=y, sr=sr)
    print(f"Analyzing duration: {duration:.1f} seconds")

    # Detect tempo if not provided
    if known_bpm is None:
        bpm, detected_beats = detect_tempo(audio_path_for_analysis)
        # Use first detected beat as start offset
        start_offset = detected_beats[0] if len(detected_beats) > 0 else 0
    else:
        bpm = known_bpm
        start_offset = 0
        print(f"\nUsing provided tempo: {bpm} BPM")

    # Generate expected metronome beats
    expected_beats = generate_expected_beats(bpm, duration, start_offset)
    print(f"\nExpected {len(expected_beats)} metronome beats")

    # Detect all onsets (drum hits)
    onsets = detect_onsets(audio_path_for_analysis)

    # Match onsets to expected beats
    timing_errors, matched_onsets = match_onsets_to_beats(onsets, expected_beats)

    # Calculate statistics
    total_beats = len(expected_beats)
    hits_detected = len(timing_errors)
    missed_beats = total_beats - hits_detected
    accuracy_percent = (hits_detected / total_beats * 100) if total_beats > 0 else 0

    print(f"\n" + "="*60)
    print("RESULTS")
    print("="*60)
    print(f"Total expected beats: {total_beats}")
    print(f"Beats you hit: {hits_detected}")
    print(f"Missed beats: {missed_beats}")
    print(f"Accuracy: {accuracy_percent:.1f}%")

    if len(timing_errors) > 0:
        avg_error = np.mean(timing_errors)
        std_error = np.std(timing_errors)
        early_hits = np.sum(timing_errors < 0)
        late_hits = np.sum(timing_errors > 0)
        on_time_hits = np.sum(np.abs(timing_errors) < 10)  # Within 10ms

        print(f"\nTiming Analysis:")
        print(f"  Average timing error: {avg_error:+.1f}ms")
        print(f"  Standard deviation: {std_error:.1f}ms")
        print(f"  On-time hits (±10ms): {on_time_hits}")
        print(f"  Early hits: {early_hits}")
        print(f"  Late hits: {late_hits}")

        if avg_error < -20:
            print(f"\n  -> You're rushing! Try to relax and stay with the click.")
        elif avg_error > 20:
            print(f"\n  -> You're dragging! Try to anticipate the beat slightly.")
        else:
            print(f"\n  -> Great timing! You're locked in with the metronome.")

    # Create visualization
    visualize_practice(y, sr, expected_beats, matched_onsets, timing_errors, bpm, audio_path)

    return {
        'bpm': bpm,
        'duration': duration,
        'total_beats': total_beats,
        'hits_detected': hits_detected,
        'missed_beats': missed_beats,
        'accuracy_percent': accuracy_percent,
        'timing_errors': timing_errors,
        'avg_error': np.mean(timing_errors) if len(timing_errors) > 0 else 0,
        'std_error': np.std(timing_errors) if len(timing_errors) > 0 else 0
    }

def visualize_practice(audio, sr, expected_beats, matched_onsets, timing_errors, bpm, audio_path):
    """
    Create visualizations of the practice session.

    Shows:
    1. Waveform with expected beats and actual hits
    2. Timing error distribution
    """
    fig, axes = plt.subplots(2, 1, figsize=(14, 8))

    # Plot 1: Waveform with beats
    ax1 = axes[0]
    librosa.display.waveshow(audio, sr=sr, alpha=0.5, ax=ax1)

    # Mark expected beats (metronome clicks)
    for beat in expected_beats:
        ax1.axvline(x=beat, color='blue', linestyle='--', alpha=0.3, linewidth=1)

    # Mark actual hits
    for onset in matched_onsets:
        ax1.axvline(x=onset, color='red', linestyle='-', alpha=0.6, linewidth=2)

    ax1.set_xlabel('Time (seconds)')
    ax1.set_ylabel('Amplitude')
    ax1.set_title(f'Drum Practice Analysis - {bpm:.1f} BPM\n'
                  f'Blue dashes = Expected beats | Red lines = Your hits')
    ax1.legend(['Audio', 'Expected beat', 'Your hit'])

    # Plot 2: Timing errors histogram
    ax2 = axes[1]
    if len(timing_errors) > 0:
        ax2.hist(timing_errors, bins=30, color='green', alpha=0.7, edgecolor='black')
        ax2.axvline(x=0, color='blue', linestyle='--', linewidth=2, label='Perfect timing')
        ax2.axvline(x=np.mean(timing_errors), color='red', linestyle='-', linewidth=2,
                   label=f'Your average: {np.mean(timing_errors):+.1f}ms')
        ax2.set_xlabel('Timing Error (milliseconds)')
        ax2.set_ylabel('Number of Hits')
        ax2.set_title('Timing Error Distribution\n'
                     f'Negative = Early | Positive = Late')
        ax2.legend()
        ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    output_path = audio_path.replace('.wav', '_practice_analysis.png')
    plt.savefig(output_path, dpi=150)
    print(f"\nVisualization saved: {output_path}")
    plt.close()

if __name__ == "__main__":
    # Analyze the practice session
    # Trim to first 30 seconds and use known BPM of 120
    results = analyze_practice_session("test1.wav", known_bpm=120, trim_duration=30)

    print("\n" + "="*60)
    print("Analysis complete! Check the PNG file for visualizations.")
    print("="*60)

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
    print(f"\nDetected chord progression:")
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
    print(f"Visualization saved: {audio_path.replace('.wav', '_chords.png')}")

    return chords

if __name__ == "__main__":
    chords = analyze_chords("17569__danglada__c-major.wav")
    print(f"\nMadmom test complete!")

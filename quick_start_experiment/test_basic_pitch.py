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
    print(f"MIDI saved: {midi_path}")

    # Display results
    print(f"\nDetected {len(note_events)} notes:")
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
    print(f"Visualization saved: {audio_path.replace('.wav', '_melody.png')}")

    return note_events

if __name__ == "__main__":
    # Test on your audio file
    notes = analyze_melody("736935__sirbagel__bass-guitar-single-ga-note.wav")
    print(f"\nBasic Pitch test complete!")

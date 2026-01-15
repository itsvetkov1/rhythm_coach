# How to Use the Drum Practice Analyzer

## What This Does

This script analyzes your drumming practice and tells you:
- **How many beats you hit** vs how many you should have hit
- **Your timing accuracy** - are you early, late, or on time?
- **Your consistency** - how much your timing varies
- **Visual feedback** - graphs showing where you hit vs where you should have hit

## Quick Start

### 1. Create Your Practice Recording

Record yourself drumming along with a metronome. The file should:
- Be named `test1.wav`
- Be in WAV format
- Contain BOTH your drumming AND the metronome click track
- Be placed in the `quick_start_experiment` folder

**Example: How to create test1.wav**
- Use your phone or computer to record
- Play a metronome (120 BPM is a good start)
- Drum along with it for 30-60 seconds
- Save as WAV format

### 2. Run the Analyzer

```bash
cd G:\git_repos\rhythm_coach\quick_start_experiment
source venv/Scripts/activate
python analyze_drum_practice.py
```

### 3. Check the Results

The script will:
1. **Print results to console** showing:
   - How many beats you hit
   - Your average timing error (in milliseconds)
   - Whether you're rushing (too early) or dragging (too late)

2. **Create a visualization** (`test1_practice_analysis.png`) with:
   - Your waveform with expected beats marked
   - A graph showing how early/late each hit was

## Understanding the Results

### Timing Errors
- **Negative numbers (e.g., -15ms)** = You're EARLY (rushing)
- **Positive numbers (e.g., +15ms)** = You're LATE (dragging)
- **Within ±10ms** = Excellent timing!
- **±10-30ms** = Good, but could be tighter
- **More than ±30ms** = Noticeable timing issues

### Accuracy Percentage
- **90-100%** = Excellent! You're hitting almost every beat
- **75-90%** = Good, but some beats were missed or too far off
- **Below 75%** = Needs work - focus on consistency

## Advanced Options

### If You Know Your BPM

If you practiced at a specific tempo (e.g., 120 BPM), you can tell the script:

Edit the last line of `analyze_drum_practice.py`:
```python
# Change this:
results = analyze_practice_session("test1.wav")

# To this (with your BPM):
results = analyze_practice_session("test1.wav", known_bpm=120)
```

This makes detection more accurate!

### Adjusting Sensitivity

If the script is detecting too many or too few hits, you can adjust sensitivity in the `detect_onsets` function:

- `sensitivity='high'` - Detects quieter hits (may pick up extra noise)
- `sensitivity='default'` - Balanced (recommended)
- `sensitivity='low'` - Only detects loud hits

## Example Output

```
============================================================
DRUM PRACTICE ANALYSIS
============================================================
Audio duration: 45.2 seconds
Audio sample rate: 192000 Hz

Detecting tempo...
Detected tempo: 120.3 BPM
Detected 85 beats

Expected 90 metronome beats

Detecting drum hits in: test1.wav
Audio sample rate: 192000 Hz
Detected 187 hits total

Matching drum hits to expected beats...
Tolerance: 150ms

============================================================
RESULTS
============================================================
Total expected beats: 90
Beats you hit: 85
Missed beats: 5
Accuracy: 94.4%

Timing Analysis:
  Average timing error: +12.3ms
  Standard deviation: 18.5ms
  On-time hits (±10ms): 45
  Early hits: 20
  Late hits: 20

  → You're slightly dragging! Try to anticipate the beat slightly.

Visualization saved: test1_practice_analysis.png
```

## Troubleshooting

### "No beats detected"
- Make sure your audio has clear metronome clicks
- Try increasing sensitivity: `detect_onsets(audio_path, sensitivity='high')`

### "Too many beats detected"
- The script might be picking up noise or ghost notes
- Try decreasing sensitivity: `detect_onsets(audio_path, sensitivity='low')`

### "Wrong BPM detected"
- Provide the BPM manually: `analyze_practice_session("test1.wav", known_bpm=120)`

## Next Steps

Once you've analyzed a few practice sessions:
1. Track your progress over time
2. Practice at different tempos
3. Focus on areas where timing is inconsistent
4. Use this data to build the full rhythm coach app!

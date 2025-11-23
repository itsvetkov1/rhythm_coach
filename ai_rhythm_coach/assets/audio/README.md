# Audio Assets

This directory contains the metronome click audio files used by the app.

## Required Files

- `click_high.wav` - High-pitched click (800 Hz) for downbeats
- `click_low.wav` - Low-pitched click (400 Hz) for other beats

## Audio Specifications

- Format: WAV (PCM 16-bit)
- Sample Rate: 44100 Hz
- Duration: ~50ms
- Channels: Mono

## Generating Audio Files

You can generate these files using the included script:

```bash
cd ai_rhythm_coach
dart run tools/generate_metronome_sounds.dart
```

Or use any audio editing software (Audacity, etc.) to create:
1. A 50ms sine wave at 800 Hz for click_high.wav
2. A 50ms sine wave at 400 Hz for click_low.wav

## Alternative: Free Sound Files

You can also download free metronome click sounds from:
- https://freesound.org/
- https://soundbible.com/

Just ensure they are in WAV format and rename them accordingly.

# AI Rhythm Coach

An Android mobile app that helps drummers and musicians improve rhythm accuracy through AI-powered coaching feedback. Users practice against a metronome, and the app analyzes their performance using onset detection algorithms and provides personalized coaching via Claude or GPT APIs.

## Features

- **Metronome Practice**: Practice with a configurable metronome (40-200 BPM)
- **Rhythm Analysis**: FFT-based onset detection to analyze timing accuracy
- **AI Coaching**: Personalized feedback from Claude or GPT APIs
- **Session History**: Stores up to 10 recent practice sessions locally
- **Detailed Stats**: View average error, consistency, and timing breakdown

## Getting Started

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Android SDK
- An API key from either:
  - [Anthropic Claude](https://console.anthropic.com/) (recommended)
  - [OpenAI GPT](https://platform.openai.com/api-keys)

### Installation

1. **Install dependencies**
   ```bash
   flutter pub get
   ```

2. **Configure AI API Keys**
   ```bash
   cp lib/config.dart.template lib/config.dart
   ```

   Then edit `lib/config.dart` and add your API keys:
   ```dart
   static const AIProvider provider = AIProvider.anthropic; // or openai
   static const String anthropicApiKey = 'your-anthropic-key-here';
   static const String openaiApiKey = 'your-openai-key-here';
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## How It Works

1. **Setup**: User sets desired BPM (40-200)
2. **Count-in**: 4-beat count-in to prepare
3. **Recording**: 60-second recording with metronome playback
4. **Analysis**: FFT-based onset detection identifies tap times
5. **AI Coaching**: Session data sent to AI API for personalized feedback
6. **Results**: Display stats and coaching feedback

## Development Commands

```bash
# Run the app
flutter run

# Run tests
flutter test

# Build APK
flutter build apk

# Analyze code
flutter analyze
```

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── config.dart                  # AI API configuration (gitignored)
├── models/                      # Data models
├── controllers/                 # State management
├── services/                    # Business logic services
├── screens/                     # UI screens
└── widgets/                     # Reusable UI components
```

## Troubleshooting

### No beats detected
- Ensure microphone permission is granted
- Tap louder or closer to the device microphone

### Audio not playing
- Test on physical device (emulator has limited audio support)
- Check that audio files exist in `assets/audio/`

### AI API errors
- Check your API key is correct in `config.dart`
- Ensure you have internet connection
- Verify you have API credits/quota available

## Limitations (MVP)

- Android only (no iOS)
- 4/4 time signature only
- Fixed 60-second sessions
- Local storage only (no cloud sync)

## License

[Add your license here]

---

**Note**: This is an MVP (Minimum Viable Product). Audio analysis accuracy may vary based on device hardware and recording conditions.

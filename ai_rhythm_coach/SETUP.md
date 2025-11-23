# Setup Guide for AI Rhythm Coach

Follow these steps to get the AI Rhythm Coach app running on your Android device.

## Prerequisites

1. **Flutter SDK** installed (version 3.9.2 or higher)
   - [Install Flutter](https://docs.flutter.dev/get-started/install)

2. **Android Studio** or Android SDK installed
   - Ensure you have Android SDK tools and an Android device/emulator

3. **AI API Key** from either:
   - [Anthropic Claude](https://console.anthropic.com/) - Recommended
   - [OpenAI GPT](https://platform.openai.com/api-keys)

## Quick Start

### 1. Install Dependencies

```bash
cd ai_rhythm_coach
flutter pub get
```

### 2. Configure API Keys

Copy the config template and add your API keys:

```bash
# Windows
copy lib\config.dart.template lib\config.dart

# macOS/Linux
cp lib/config.dart.template lib/config.dart
```

Edit `lib/config.dart`:

```dart
enum AIProvider { anthropic, openai }

class AIConfig {
  // Choose your provider
  static const AIProvider provider = AIProvider.anthropic;  // or AIProvider.openai

  // Add your API keys here
  static const String anthropicApiKey = 'sk-ant-your-key-here';
  static const String openaiApiKey = 'sk-your-key-here';

  // ... rest of config
}
```

**IMPORTANT**: Never commit `lib/config.dart` to version control. It's already in `.gitignore`.

### 3. Connect Android Device

#### Physical Device (Recommended for audio testing):
1. Enable USB debugging on your Android device:
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times to enable Developer Options
   - Go to Settings → Developer Options
   - Enable "USB Debugging"
2. Connect device via USB
3. Verify connection: `flutter devices`

#### Emulator:
```bash
# List available emulators
flutter emulators

# Launch an emulator
flutter emulators --launch <emulator_id>
```

**Note**: Audio features work best on physical devices. Emulators have limited audio support.

### 4. Run the App

```bash
flutter run
```

Or select a specific device:
```bash
flutter run -d <device_id>
```

## Verify Installation

### Run Tests
```bash
flutter test
```

### Check for Issues
```bash
flutter doctor
flutter analyze
```

## First Use

1. **Grant Permissions**: When you first start the app, grant microphone permission
2. **Set BPM**: Use the +/- buttons to set your desired tempo (40-200 BPM)
3. **Start Practice**: Tap "Start Practice"
4. **Count-in**: Listen for the 4-beat count-in
5. **Play Along**: Tap along with the metronome for 60 seconds
6. **View Results**: See your stats and AI coaching feedback

## Troubleshooting

### "No beats detected"
- Grant microphone permission in app settings
- Tap louder or closer to the microphone
- Try on a physical device (not emulator)

### "Microphone permission denied"
- Go to Android Settings → Apps → AI Rhythm Coach → Permissions
- Enable Microphone permission

### "AI coaching generation failed"
- Check your internet connection
- Verify API key is correct in `lib/config.dart`
- Check API credits/quota at provider's website
- Ensure config.dart exists (copied from template)

### Build errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Audio not playing
- Test on physical device (emulator audio is limited)
- Check that audio files exist: `assets/audio/click_high.wav` and `click_low.wav`
- Verify audio files in pubspec.yaml assets section

## Building for Release

### Debug APK
```bash
flutter build apk --debug
```

### Release APK
```bash
flutter build apk --release
```

The APK will be in: `build/app/outputs/flutter-apk/app-release.apk`

### App Bundle (for Google Play)
```bash
flutter build appbundle --release
```

## Development

### Hot Reload
While the app is running, press `r` in the terminal for hot reload.

### Hot Restart
Press `R` for hot restart (full app restart).

### Debugging
```bash
# Run with debug info
flutter run --debug

# View logs
flutter logs
```

## Need Help?

- Check the [README.md](README.md) for more details
- Review [CLAUDE.md](CLAUDE.md) for architecture documentation
- Flutter docs: https://docs.flutter.dev/

## API Costs

**Important**: The app makes API calls to Claude/GPT for each practice session. Be aware of:
- Anthropic Claude pricing: https://www.anthropic.com/pricing
- OpenAI GPT pricing: https://openai.com/pricing

Typical cost per session: ~$0.01-0.03 depending on model and provider.

---

Happy practicing! 🥁

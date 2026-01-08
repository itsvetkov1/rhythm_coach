# Building and Testing the APK

This document explains how to build and test the AI Rhythm Coach Android APK with the headphones fix.

## Option 1: Download from GitHub Actions (Recommended)

The easiest way to get the APK is to download it from GitHub Actions:

1. Go to the repository on GitHub
2. Click on the **Actions** tab
3. Find the latest "Build Android APK" workflow run
4. Scroll down to the **Artifacts** section
5. Download the `debug-apk` artifact
6. Extract the ZIP file to get `app-debug.apk`
7. Transfer the APK to your Android device and install it

**Note**: The APK is automatically built whenever you push to a `claude/**` branch or the main branch.

## Option 2: Build Locally

If you have Flutter installed on your machine, you can build the APK locally:

### Prerequisites
- Flutter SDK (3.24.0 or later)
- Java JDK 17
- Android SDK

### Quick Build

```bash
# From the repository root
./build-apk.sh
```

The APK will be created at:
```
ai_rhythm_coach/build/app/outputs/flutter-apk/app-debug.apk
```

### Manual Build Steps

```bash
# Navigate to the Flutter project
cd ai_rhythm_coach

# Get dependencies
flutter pub get

# Build debug APK
flutter build apk --debug
```

## Installing the APK

### Method 1: Via ADB (Developer Mode)

1. Enable USB debugging on your Android device:
   - Go to **Settings** > **About Phone**
   - Tap **Build Number** 7 times to enable Developer Options
   - Go to **Settings** > **Developer Options**
   - Enable **USB Debugging**

2. Connect your device via USB

3. Install the APK:
   ```bash
   adb install ai_rhythm_coach/build/app/outputs/flutter-apk/app-debug.apk
   ```

### Method 2: Manual Installation

1. Transfer the APK to your Android device (via USB, cloud storage, etc.)
2. On your device, enable **Install Unknown Apps** for your file manager:
   - Go to **Settings** > **Security** > **Install Unknown Apps**
   - Select your file manager app and allow it to install apps
3. Open the APK file on your device
4. Tap **Install**

## Testing the Headphones Fix

Once installed, follow these steps to verify the fix works:

### Step 1: Initial Launch
1. Launch the app
2. **Verify**: Headphones warning dialog appears immediately
3. **Verify**: Dialog explains why headphones are required
4. **Verify**: Dialog cannot be dismissed by tapping outside

### Step 2: Connect Headphones
1. Connect wired or Bluetooth headphones to your device
2. Tap "Headphones Connected" in the dialog

### Step 3: Practice Session
1. Set BPM (try 120 BPM for testing)
2. Tap "Start Practice"
3. **Verify**: You hear the 4-beat count-in in your headphones
4. **Verify**: Metronome clicks play through headphones only
5. During the session, clap or tap along with the metronome
6. Wait for the 60-second session to complete

### Step 4: Verify Recording
After the session completes, the app will analyze your recording. The key test is:

**Expected Result**:
- The rhythm analysis should detect YOUR claps/taps
- It should NOT detect the metronome clicks
- You should get meaningful coaching feedback

**How to verify the fix is working**:
1. Check that you receive specific feedback about your timing
2. The number of detected beats should match your actual taps (not the metronome beats)
3. If you intentionally played off-beat, the feedback should reflect that

### Step 5: Negative Test (Without Headphones)

To verify the problem existed before:

1. Close and reopen the app
2. **Don't connect headphones** (ignore the warning or tap "Not Now")
3. Try a practice session
4. **Expected**: The analysis will likely be incorrect because it detects metronome clicks

## Troubleshooting

### "App not installed" error
- Make sure you've enabled installation from unknown sources
- Check that you have enough storage space
- Try uninstalling any previous version first

### No sound during practice
- Check that your device volume is not muted
- Verify headphones are properly connected
- Check that app has microphone permissions

### Microphone permission denied
- Go to **Settings** > **Apps** > **AI Rhythm Coach** > **Permissions**
- Enable **Microphone** permission

### Recording doesn't capture your performance
- Speak louder or tap harder
- Make sure microphone is not blocked
- Check that headphones don't have a built-in mic that's being used instead

## APK Details

- **Build Type**: Debug
- **Size**: ~25-30 MB (debug builds are larger than release builds)
- **Minimum Android Version**: Android 8.0 (API level 26)
- **Permissions Required**:
  - Microphone (for recording)
  - Storage (for saving session data)

## Feedback

If you encounter any issues:
1. Check the app shows the headphones warning on launch
2. Verify your headphones are properly connected
3. Test with different headphone types (wired, Bluetooth)
4. Try different BPM values (40, 80, 120, 160, 200)

Report any issues with:
- Device model and Android version
- Headphone type (wired/Bluetooth)
- Steps to reproduce the issue
- Expected vs actual behavior

## Next Steps After Testing

Once you've verified the fix works:
1. Test with multiple Android devices if possible
2. Try both wired and Bluetooth headphones
3. Test various BPM settings
4. Verify onset detection accuracy is significantly improved
5. Confirm that without headphones, the issue still occurs (validates the fix)

The fix is successful if:
- ✅ Warning dialog appears on app launch
- ✅ Metronome plays through headphones only
- ✅ Recording captures your performance clearly
- ✅ Rhythm analysis detects your beats (not metronome)
- ✅ Coaching feedback is accurate and helpful

# Audio Input/Output Separation Test Plan

## Overview
This document describes how to test and verify that the audio input/output separation fix is working correctly.

## Fix Summary
**Problem**: Metronome clicks were bleeding into microphone recordings, causing inaccurate rhythm analysis.

**Solution**: Configured audio focus using flutter_sound's `setAudioFocus()` API with:
- `SessionCategory.playAndRecord` - Enables simultaneous playback and recording
- `AudioFocus.requestFocusAndKeepOthers` - Maintains proper audio routing
- Audio flags for headphones, bluetooth, and A2DP support
- Automatic echo cancellation via playAndRecord category

**Expected Result**:
- Metronome plays through headphones/bluetooth ONLY
- Microphone records user's performance ONLY (no metronome bleed)

---

## Prerequisites

### Required Equipment
- [ ] Android device (physical device required - emulator has limited audio support)
- [ ] Wired headphones OR Bluetooth headphones
- [ ] USB cable for ADB connection (for log inspection)

### Build the App
```bash
cd /home/user/rhythm_coach
./build-apk.sh
```

Or manually:
```bash
cd ai_rhythm_coach
flutter pub get
flutter build apk --debug
```

Install on device:
```bash
adb install build/app/outputs/flutter-apk/app-debug.apk
```

---

## Test Procedures

### Test 1: Verify Audio Focus Configuration (Quick Check)
**Duration**: 1 minute

1. Connect device via USB and start ADB logcat:
   ```bash
   adb logcat | grep "AudioService"
   ```

2. Launch the app

3. Tap "Start Practice" (after dismissing headphones warning)

4. **VERIFY** you see these log messages:
   ```
   AudioService: Player configured - output routes to connected audio device
   AudioService: Recorder configured - microphone input with echo cancellation
   AudioService: ✓ Audio separation configured
   AudioService: Metronome -> Headphones/Bluetooth | Recording <- Microphone only
   ```

**Result**: ✅ PASS if all messages appear, ❌ FAIL if configuration failed or missing

---

### Test 2: Headphones Metronome Output Test
**Duration**: 2 minutes

1. **Connect headphones** (wired or bluetooth)

2. Launch app and tap "Start Practice"

3. During count-in and recording:
   - **VERIFY**: You hear metronome clicks clearly in headphones
   - **VERIFY**: No audible metronome sound from phone speaker
   - **VERIFY**: Phone microphone is not near headphones (hold phone away)

4. Tap along with the metronome using your voice or clapping

**Result**: ✅ PASS if metronome plays ONLY in headphones

---

### Test 3: Recording Playback Analysis (Critical Test)
**Duration**: 5 minutes

**Objective**: Verify recorded audio does NOT contain metronome clicks

1. **Setup**:
   - Connect headphones
   - Set BPM to 120 (clear, distinct clicks)
   - Hold phone microphone away from headphones (30cm minimum)

2. **Record Session**:
   - Tap "Start Practice"
   - During 60-second session: **Stay silent for first 10 seconds**
   - Then clap or tap along with metronome for remaining time
   - Complete full 60-second session

3. **Playback Analysis**:
   - On results screen, tap playback button
   - Listen carefully to recording

4. **VERIFY** during the silent first 10 seconds:
   - ✅ You should hear: **Nothing** or very quiet background noise
   - ❌ You should NOT hear: Metronome clicks or beeps

5. **VERIFY** during the clapping section:
   - ✅ You should hear: Your claps/taps clearly
   - ❌ You should NOT hear: Metronome clicks mixed with your claps

**Result**:
- ✅ PASS if NO metronome audible in recording
- ❌ FAIL if metronome clicks are audible in recording (separation not working)

---

### Test 4: Advanced: Audio File Inspection (Optional)
**Duration**: 5 minutes

**Objective**: Inspect raw audio waveform to confirm no metronome bleed

1. After completing Test 3, find the recording file:
   ```bash
   adb shell ls /data/data/com.example.ai_rhythm_coach/app_flutter/
   ```

2. Pull the most recent recording:
   ```bash
   adb pull /data/data/com.example.ai_rhythm_coach/app_flutter/recording_TIMESTAMP.wav
   ```

3. Open in audio editor (Audacity, WavePad, etc.)

4. **Inspect waveform** during silent period:
   - Zoom in on the first 10 seconds
   - Check amplitude levels
   - **VERIFY**: No regular spikes at 120 BPM intervals (0.5s apart)

5. **Visual check**:
   - ✅ PASS: Flat or low-amplitude noise only
   - ❌ FAIL: Clear periodic spikes every 0.5s (metronome bleed)

---

### Test 5: Bluetooth Headphones Test
**Duration**: 3 minutes

1. **Connect Bluetooth headphones**

2. Verify bluetooth connection in Android settings

3. Launch app and start practice session

4. **VERIFY**:
   - Metronome plays through bluetooth headphones
   - Recording captures your performance only
   - No metronome audible in recording playback

**Result**: ✅ PASS if bluetooth routing works correctly

---

### Test 6: Rhythm Analysis Accuracy Test
**Duration**: 5 minutes

**Objective**: Verify accurate rhythm analysis without metronome interference

1. **Setup**:
   - Headphones connected
   - BPM set to 100 (comfortable tempo)

2. **Record perfect performance**:
   - Tap/clap exactly on beat for entire 60 seconds
   - Try to be as accurate as possible

3. **Check Results**:
   - View results screen
   - Check average error and consistency metrics

4. **VERIFY**:
   - ✅ Average error should be < 50ms (reasonably accurate)
   - ✅ Consistency should be reasonable (varies by user skill)
   - ❌ NOT: Average error > 100ms or impossibly low (< 5ms) suggesting metronome detection

**Result**:
- ✅ PASS if metrics reflect human performance (not metronome detection)
- ❌ FAIL if metrics suggest metronome is being detected as taps

---

## Common Issues and Troubleshooting

### Issue: Configuration Failed Warning
**Symptom**: Log shows "⚠ Failed to configure audio routing"

**Causes**:
- flutter_sound API mismatch
- Android version incompatibility
- Enum values not found

**Debug**:
```bash
adb logcat | grep -i "flutter_sound\|AudioService"
```

**Solution**: Check exact error message and verify flutter_sound version 9.2.13 is installed

---

### Issue: Still Hearing Metronome in Recording
**Symptom**: Test 3 fails - metronome audible in playback

**Possible Causes**:
1. **Physical bleed**: Headphones too loud, phone mic too close
   - **Solution**: Lower volume, increase distance (>50cm)

2. **Headphones not connected**: Using phone speaker
   - **Solution**: Verify headphones connected in Android settings

3. **Configuration not applied**: setAudioFocus() failed silently
   - **Solution**: Check logs for configuration success messages

4. **Hardware limitation**: Some Android devices have poor separation
   - **Solution**: Test on different device

---

### Issue: No Sound from Headphones
**Symptom**: Metronome plays from speaker instead of headphones

**Causes**:
- Audio routing not configured correctly
- audioFlags not working on this Android version
- Headphones not properly connected

**Debug**:
1. Check headphones work with other apps
2. Verify logs show configuration success
3. Try different headphones (wired vs bluetooth)

---

## Test Results Template

### Device Info
- **Device**: _____________________
- **Android Version**: _____________________
- **Headphones Type**: Wired / Bluetooth

### Test Results
- [ ] Test 1: Audio Focus Configuration - PASS / FAIL
- [ ] Test 2: Headphones Metronome Output - PASS / FAIL
- [ ] Test 3: Recording Playback Analysis - PASS / FAIL
- [ ] Test 4: Audio File Inspection (Optional) - PASS / FAIL
- [ ] Test 5: Bluetooth Headphones - PASS / FAIL
- [ ] Test 6: Rhythm Analysis Accuracy - PASS / FAIL

### Notes
_________________________________________________
_________________________________________________
_________________________________________________

### Overall Result
- ✅ **FIX VERIFIED** - Audio separation working correctly
- ⚠️ **PARTIAL** - Some issues remain (describe above)
- ❌ **FIX NOT WORKING** - Metronome still bleeding into recording

---

## Success Criteria

The fix is considered **VERIFIED** if:
1. ✅ Test 1 shows proper configuration logs
2. ✅ Test 3 shows NO audible metronome in recording playback
3. ✅ Test 6 shows reasonable rhythm analysis metrics

**If all three pass, the audio separation fix is working correctly.**

---

## Next Steps After Testing

### If Tests Pass ✅
1. Mark issue as resolved
2. Push changes to main branch
3. Close related issues/PRs
4. Update release notes

### If Tests Fail ❌
1. Document which tests failed
2. Capture ADB logs during failure
3. Pull and inspect audio recording files
4. Report findings with:
   - Device model and Android version
   - Exact test that failed
   - Log output
   - Audio file samples (if possible)

---

## References
- flutter_sound API: https://pub.dev/packages/flutter_sound
- Session Management: https://github.com/Canardoux/flutter_sound/wiki/Session-Management
- Android Audio Focus: https://developer.android.com/guide/topics/media-apps/audio-focus

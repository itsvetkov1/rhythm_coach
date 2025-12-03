#!/bin/bash

# Audio Separation Test Helper Script
# This script monitors ADB logs to verify audio configuration is working

set -e

echo "========================================"
echo "Audio Separation Test Helper"
echo "========================================"
echo ""

# Check if ADB is installed
if ! command -v adb &> /dev/null; then
    echo "❌ Error: ADB is not installed or not in PATH"
    echo ""
    echo "Please install Android SDK Platform Tools:"
    echo "  - Linux: sudo apt install adb"
    echo "  - Mac: brew install android-platform-tools"
    echo "  - Windows: Download from https://developer.android.com/tools/releases/platform-tools"
    exit 1
fi

# Check if device is connected
if ! adb devices | grep -q "device$"; then
    echo "❌ Error: No Android device connected"
    echo ""
    echo "Please connect your Android device via USB and enable USB debugging"
    echo ""
    echo "To enable USB debugging:"
    echo "  1. Go to Settings > About Phone"
    echo "  2. Tap 'Build Number' 7 times to enable Developer Options"
    echo "  3. Go to Settings > Developer Options"
    echo "  4. Enable 'USB Debugging'"
    echo ""
    exit 1
fi

echo "✓ ADB found"
DEVICE=$(adb devices | grep "device$" | head -1 | awk '{print $1}')
echo "✓ Device connected: $DEVICE"
echo ""

echo "📱 Clearing old logs..."
adb logcat -c

echo ""
echo "🎧 Instructions:"
echo "  1. Connect your headphones to the device"
echo "  2. Launch the AI Rhythm Coach app"
echo "  3. Tap 'Start Practice'"
echo ""
echo "This script will monitor logs and verify audio configuration..."
echo ""
echo "Press Ctrl+C to stop monitoring"
echo ""
echo "========================================"
echo "Monitoring AudioService logs..."
echo "========================================"
echo ""

# Track if we've seen the configuration messages
PLAYER_CONFIGURED=false
RECORDER_CONFIGURED=false
SEPARATION_CONFIRMED=false

# Monitor logs
adb logcat | grep --line-buffered "AudioService" | while read -r line; do
    echo "$line"

    # Check for key configuration messages
    if echo "$line" | grep -q "Player configured - output routes to connected audio device"; then
        PLAYER_CONFIGURED=true
        echo ""
        echo "✅ Player audio routing configured!"
        echo ""
    fi

    if echo "$line" | grep -q "Recorder configured - microphone input with echo cancellation"; then
        RECORDER_CONFIGURED=true
        echo ""
        echo "✅ Recorder audio routing configured!"
        echo ""
    fi

    if echo "$line" | grep -q "✓ Audio separation configured"; then
        SEPARATION_CONFIRMED=true
        echo ""
        echo "========================================"
        echo "✅ ✅ ✅  AUDIO SEPARATION VERIFIED  ✅ ✅ ✅"
        echo "========================================"
        echo ""
        echo "Configuration successful! The fix is working:"
        echo "  • Metronome output → Headphones/Bluetooth"
        echo "  • Microphone input ← User performance only"
        echo ""
        echo "Now test the recording playback:"
        echo "  1. Complete the practice session"
        echo "  2. On results screen, tap playback"
        echo "  3. Listen carefully - you should NOT hear metronome clicks"
        echo ""
        echo "If you hear only your performance (no metronome):"
        echo "  ✅ Audio separation is working correctly!"
        echo ""
        echo "If you hear metronome clicks in the recording:"
        echo "  ❌ Issue persists - see AUDIO_SEPARATION_TEST_PLAN.md"
        echo ""
    fi

    if echo "$line" | grep -q "⚠ Failed to configure audio routing"; then
        echo ""
        echo "========================================"
        echo "❌  CONFIGURATION FAILED  ❌"
        echo "========================================"
        echo ""
        echo "Audio routing configuration failed!"
        echo "This may indicate:"
        echo "  • flutter_sound API compatibility issue"
        echo "  • Android version incompatibility"
        echo "  • Missing enum values"
        echo ""
        echo "Check the full error message above."
        echo "See AUDIO_SEPARATION_TEST_PLAN.md for troubleshooting."
        echo ""
    fi
done

echo ""
echo "Monitoring stopped."
echo ""

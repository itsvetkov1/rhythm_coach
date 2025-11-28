#!/bin/bash

# Build Debug APK for AI Rhythm Coach
# This script builds a debug APK that can be installed on Android devices for testing

set -e

echo "======================================"
echo "Building AI Rhythm Coach Debug APK"
echo "======================================"
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null
then
    echo "❌ Error: Flutter is not installed or not in PATH"
    echo ""
    echo "Please install Flutter from: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✓ Flutter found: $(flutter --version | head -1)"
echo ""

# Navigate to project directory
cd ai_rhythm_coach

echo "📦 Getting dependencies..."
flutter pub get
echo ""

echo "🔍 Running static analysis..."
flutter analyze --no-fatal-infos || true
echo ""

echo "🧪 Running tests..."
flutter test || echo "⚠️  Some tests failed (continuing with build)"
echo ""

echo "🔨 Building debug APK..."
flutter build apk --debug

echo ""
echo "======================================"
echo "✅ Build Complete!"
echo "======================================"
echo ""
echo "APK Location:"
echo "  $(pwd)/build/app/outputs/flutter-apk/app-debug.apk"
echo ""
echo "APK Size:"
ls -lh build/app/outputs/flutter-apk/app-debug.apk | awk '{print "  " $5}'
echo ""
echo "To install on your device:"
echo "  1. Enable USB debugging on your Android device"
echo "  2. Connect device via USB"
echo "  3. Run: adb install build/app/outputs/flutter-apk/app-debug.apk"
echo ""
echo "Or transfer the APK to your device and install manually"
echo ""

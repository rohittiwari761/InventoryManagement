#!/bin/bash
# Local Flutter App Script

echo "📱 Starting Flutter App..."
echo ""

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -1)"
echo ""

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

echo ""
echo "🎯 Choose your platform:"
echo "1) iOS Simulator"
echo "2) Android Emulator"
echo "3) Physical Device (Android/iOS)"
echo ""
read -p "Enter choice (1-3): " choice

case $choice in
    1)
        echo "🍎 Launching iOS Simulator..."
        flutter run -d ios
        ;;
    2)
        echo "🤖 Launching Android Emulator..."
        flutter run -d android
        ;;
    3)
        echo "📱 Launching on Physical Device..."
        echo "Make sure device is connected and USB debugging is enabled"
        flutter run
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

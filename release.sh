#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "=== MarkRead Release Builder ==="
echo ""

# Check for keystore
if [ ! -f "android/app/upload-keystore.jks" ]; then
  echo "ERROR: Keystore not found at android/app/upload-keystore.jks"
  echo "Run the keystore generation command first."
  exit 1
fi

if [ ! -f "android/key.properties" ]; then
  echo "ERROR: key.properties not found at android/key.properties"
  exit 1
fi

# Bump version if requested
VERSION_CODE=$(grep 'version:' pubspec.yaml | head -1 | awk '{print $2}' | cut -d'+' -f2)
echo "Version code: $VERSION_CODE"

# Clean and analyze
echo ""
echo "--- Running analysis ---"
flutter analyze

# Build release APK (arm64 only)
echo ""
echo "--- Building release APK ---"
flutter build apk --release --target-platform android-arm64

echo ""
echo "=== Build Complete ==="
echo ""
echo "Artifacts:"
echo "  APK:  build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "Next steps:"
echo "  - Test APK on device: flutter install"
echo "  - Tag release: git tag v$(grep 'version:' pubspec.yaml | head -1 | awk '{print $2}' | cut -d'+' -f1)"

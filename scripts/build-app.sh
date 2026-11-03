#!/bin/bash
# Builds "dist/MarkTheRoughcut.app" as a universal binary (Apple Silicon + Intel) and "dist/MarkTheRoughcut-<version>.zip".
# Usage: scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=1.0.0          # CFBundleShortVersionString (numbers only)
RELEASE=1.0.0-beta.1   # tag and zip name
BUILD=1
APP=dist/MarkTheRoughcut.app

swift build -c release --arch arm64
swift build -c release --arch x86_64
mkdir -p .build/universal
lipo -create .build/arm64-apple-macosx/release/MarkTheRoughcut .build/x86_64-apple-macosx/release/MarkTheRoughcut \
  -output .build/universal/MarkTheRoughcut

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/universal/MarkTheRoughcut "$APP/Contents/MacOS/"
cp -R Resources/fonts "$APP/Contents/Resources/"
for l in Resources/*.lproj; do [ -d "$l" ] && cp -R "$l" "$APP/Contents/Resources/"; done
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
if [ -f scripts/make-icon.swift ]; then
  ICONSET=$(mktemp -d)/AppIcon.iconset
  swift scripts/make-icon.swift "$ICONSET" >/dev/null
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>MarkTheRoughcut</string>
  <key>CFBundleExecutable</key><string>MarkTheRoughcut</string>
  <key>CFBundleIdentifier</key><string>io.github.moritz-poth.marktheroughcut</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>MarkTheRoughcutRelease</key><string>$RELEASE</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 Moritz Poth. GPL-3.0-or-later.</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>de</string></array>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleDocumentTypes</key>
  <array><dict>
    <key>CFBundleTypeName</key><string>Movie</string>
    <key>CFBundleTypeRole</key><string>Viewer</string>
    <key>LSHandlerRank</key><string>Alternate</string>
    <key>LSItemContentTypes</key><array><string>public.movie</string></array>
  </dict></array>
</dict>
</plist>
PLIST
# ad-hoc signed (no Apple Developer account): macOS needs "Open Anyway" once, see README
codesign --force --deep --sign - "$APP"
rm -f "dist/MarkTheRoughcut-$RELEASE.zip"
ditto -c -k --keepParent "$APP" "dist/MarkTheRoughcut-$RELEASE.zip"
echo "Done: $APP, dist/MarkTheRoughcut-$RELEASE.zip"

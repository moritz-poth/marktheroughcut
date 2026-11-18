#!/bin/bash
# Builds "dist/MarkTheRoughcut.app" as a universal binary (Apple Silicon + Intel), "dist/MarkTheRoughcut-<version>.zip"
# (+ .sig, for the updater) and "dist/MarkTheRoughcut-<version>.dmg" (for downloads). Needs create-dmg (Homebrew).
# Usage: scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=1.0.0          # CFBundleShortVersionString (numbers only)
RELEASE=1.0.0-beta.4   # tag and zip name
BUILD=4
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
cp -R Resources/help "$APP/Contents/Resources/"   # manual, one Markdown file per language
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
ICONSET=$(mktemp -d)/AppIcon.iconset
swift scripts/make-icon.swift "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

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
  <key>CFBundleLocalizations</key><array><string>en</string><string>de</string><string>fr</string><string>es</string></array>
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
# old zip and signature go first: a run that fails later never leaves a new zip next to an old .sig
rm -f "dist/MarkTheRoughcut-$RELEASE.zip" "dist/MarkTheRoughcut-$RELEASE.zip.sig"
ditto -c -k --keepParent "$APP" "dist/MarkTheRoughcut-$RELEASE.zip"
# download image: the shared moe-apps DMG window (660 × 400, split background, motion trail); the updater keeps
# using the zip. create-dmg arranges the window through the Finder (needs Finder automation once).
DMG="dist/MarkTheRoughcut-$RELEASE.dmg"
# never touch someone else's volume: the Finder's disk "MarkTheRoughcut" below must be ours
if ls /Volumes | grep -Eq '^MarkTheRoughcut( [0-9]+)?$'; then echo "a volume \"MarkTheRoughcut\" is mounted – eject it first" >&2; exit 1; fi
STAGE=.build/dmg-stage
rm -rf "$STAGE" "$DMG"; mkdir -p "$STAGE"
ditto "$APP" "$STAGE/MarkTheRoughcut.app"
swift scripts/make-dmg-background.swift "$ICONSET/icon_512x512@2x.png" .build/dmg-bg.png 1
swift scripts/make-dmg-background.swift "$ICONSET/icon_512x512@2x.png" .build/dmg-bg@2x.png 2
tiffutil -cathidpicheck .build/dmg-bg.png .build/dmg-bg@2x.png -out .build/dmg-background.tiff 2>/dev/null
create-dmg --volname MarkTheRoughcut --window-size 660 400 --icon-size 128 \
  --icon "MarkTheRoughcut.app" 170 188 --app-drop-link 490 188 --hide-extension "MarkTheRoughcut.app" \
  --background .build/dmg-background.tiff --no-internet-enable "$DMG" "$STAGE" >/dev/null
rm -rf "$STAGE"
# update signature: installed apps only accept zips signed with the key in this Mac's Keychain
if PUB=$(swift scripts/update-key.swift public 2>/dev/null) && grep -q "\"$PUB\"" Sources/MarkTheRoughcut/Updater.swift \
   && swift scripts/update-key.swift sign "dist/MarkTheRoughcut-$RELEASE.zip"; then
  echo "Done: $APP, $DMG, dist/MarkTheRoughcut-$RELEASE.zip (+ .sig – upload all three)"
else
  echo "Done: $APP, dist/MarkTheRoughcut-$RELEASE.zip – NOT SIGNED (no update key, or it differs from Updater.publicKey): not releasable" >&2
fi

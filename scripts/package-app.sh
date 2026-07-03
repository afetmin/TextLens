#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

swift build -c release

EXECUTABLE="$ROOT_DIR/.build/release/TextLens"
APP_BUNDLE="$ROOT_DIR/.build/TextLens.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
APP_ICON="$ROOT_DIR/Resources/AppIcon.icns"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"
cp "$EXECUTABLE" "$MACOS/TextLens"
cp "$APP_ICON" "$RESOURCES/AppIcon.icns"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TextLens</string>
    <key>CFBundleIdentifier</key>
    <string>com.ranxiu.TextLens</string>
    <key>CFBundleName</key>
    <string>TextLens</string>
    <key>CFBundleDisplayName</key>
    <string>文镜</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 ranxiu</string>
</dict>
</plist>
PLIST

chmod +x "$MACOS/TextLens"

if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
    codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
else
    codesign --force --deep --sign "$CODESIGN_IDENTITY" \
        --options runtime \
        --timestamp \
        "$APP_BUNDLE" >/dev/null
fi

echo "$APP_BUNDLE"

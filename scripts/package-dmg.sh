#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
NOTARIZE="${NOTARIZE:-0}"
DMG_NAME="${DMG_NAME:-TextLens-${APP_VERSION}.dmg}"

DIST_DIR="$ROOT_DIR/.build/dist"
DMG_ROOT="$ROOT_DIR/.build/dmg"
STAGING_DIR="$DMG_ROOT/TextLens"
DMG_PATH="$DIST_DIR/$DMG_NAME"
APP_BUNDLE="$("$ROOT_DIR/scripts/package-app.sh" | tail -n 1)"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"

ditto "$APP_BUNDLE" "$STAGING_DIR/TextLens.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "TextLens" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -ov \
    "$DMG_PATH" >/dev/null

if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
    codesign --force --sign "$CODESIGN_IDENTITY" --timestamp "$DMG_PATH" >/dev/null
fi

hdiutil verify "$DMG_PATH" >/dev/null

if [[ "$NOTARIZE" == "1" ]]; then
    if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
        echo "NOTARIZE=1 requires CODESIGN_IDENTITY to be a Developer ID Application certificate." >&2
        exit 1
    fi

    if [[ -n "${NOTARY_PROFILE:-}" ]]; then
        xcrun notarytool submit "$DMG_PATH" \
            --keychain-profile "$NOTARY_PROFILE" \
            --wait
    elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
        xcrun notarytool submit "$DMG_PATH" \
            --apple-id "$APPLE_ID" \
            --team-id "$APPLE_TEAM_ID" \
            --password "$APPLE_APP_PASSWORD" \
            --wait
    else
        echo "NOTARIZE=1 requires NOTARY_PROFILE or APPLE_ID + APPLE_TEAM_ID + APPLE_APP_PASSWORD." >&2
        exit 1
    fi

    xcrun stapler staple "$DMG_PATH"
    spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH"
fi

echo "$DMG_PATH"

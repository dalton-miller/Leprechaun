#!/bin/bash
# package.sh — Build, sign, and package Leprechaun as a DMG
#
# Usage:
#   ./package.sh                          # Build + DMG (no signing)
#   ./package.sh --sign "Developer ID"   # Build + sign + DMG
#   ./package.sh --sign "Developer ID" --notarize  # + notarize
#
# Prerequisites for signing/notarization:
#   - Apple Developer Program membership
#   - "Developer ID Application" certificate in Keychain
#   - App-specific password for notarization (stored in keychain)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/release"
APP_NAME="Leprechaun"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
IDENTIFIER="com.backupthing.app"
VERSION="0.1.0"

# Defaults
SIGN_IDENTITY=""
NOTARIZE=false
APP_SPECIFIC_PASSWORD=""
TEAM_ID=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --sign)
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        --notarize)
            NOTARIZE=true
            shift
            ;;
        --team-id)
            TEAM_ID="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# ─────────────────────────────────────────────
# Download rclone if not present
RCLONE_VERSION="1.73.4"
RESOURCES_DIR="$SCRIPT_DIR/Sources/Leprechaun/Resources"
download_rclone() {
    local arch="$1"
    local dir_arch
    case "$arch" in
        amd64) dir_arch="amd64" ;;
        *)     dir_arch="$arch" ;;
    esac
    local zip_name="rclone-${arch}.zip"
    local dir_name="rclone-v${RCLONE_VERSION}-osx-${dir_arch}"
    local out_name="rclone-darwin-${arch}"

    if [ -f "$RESOURCES_DIR/$out_name" ]; then
        echo "  ▸ $out_name already present"
        return
    fi

    echo "▸ Downloading rclone v${RCLONE_VERSION} darwin-${arch}…"
    mkdir -p "$RESOURCES_DIR"
    curl -fsSL "https://downloads.rclone.org/v${RCLONE_VERSION}/${dir_name}.zip" -o "/tmp/$zip_name"
    unzip -o "/tmp/$zip_name" -d "/tmp/rclone-tmp-${arch}"
    cp "/tmp/rclone-tmp-${arch}/${dir_name}/rclone" "$RESOURCES_DIR/$out_name"
    chmod +x "$RESOURCES_DIR/$out_name"
    rm -rf "/tmp/$zip_name" "/tmp/rclone-tmp-${arch}"
}

echo "▸ Ensuring rclone binaries are present…"
download_rclone "arm64"
download_rclone "amd64"

# ─────────────────────────────────────────────
echo "▸ Building release…"
swift build --configuration release --product "$APP_NAME"

# ─────────────────────────────────────────────
echo "▸ Creating .app bundle…"

# Clean previous build
rm -rf "$APP_BUNDLE"

# Create bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Info.plist
cp "$SCRIPT_DIR/Leprechaun-Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy rclone binaries as resources
cp "$SCRIPT_DIR/Sources/Leprechaun/Resources/rclone-darwin-arm64" \
   "$APP_BUNDLE/Contents/Resources/"
cp "$SCRIPT_DIR/Sources/Leprechaun/Resources/rclone-darwin-x86_64" \
   "$APP_BUNDLE/Contents/Resources/"
chmod +x "$APP_BUNDLE/Contents/Resources/rclone-darwin-arm64"
chmod +x "$APP_BUNDLE/Contents/Resources/rclone-darwin-x86_64"

# ─────────────────────────────────────────────
if [ -n "$SIGN_IDENTITY" ]; then
    echo "▸ Code signing with: $SIGN_IDENTITY"

    ENTITLEMENTS="$SCRIPT_DIR/Leprechaun.entitlements"

    # Sign rclone binaries first
    codesign --force --options runtime --sign "$SIGN_IDENTITY" \
        "$APP_BUNDLE/Contents/Resources/rclone-darwin-arm64"
    codesign --force --options runtime --sign "$SIGN_IDENTITY" \
        "$APP_BUNDLE/Contents/Resources/rclone-darwin-x86_64"

    # Sign the main executable
    codesign --force --options runtime --entitlements "$ENTITLEMENTS" \
        --sign "$SIGN_IDENTITY" \
        "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

    # Sign the app bundle
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
        "$APP_BUNDLE"

    # Verify
    codesign --verify --verbose "$APP_BUNDLE"
    echo "✓ Code signing complete"
fi

# ─────────────────────────────────────────────
echo "▸ Creating DMG…"

DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
rm -f "$DMG_PATH"

# Create DMG with a nice layout
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$APP_BUNDLE" \
    -ov -format UDZO \
    "$DMG_PATH"

echo "✓ DMG created: $DMG_PATH"

# ─────────────────────────────────────────────
if [ "$NOTARIZE" = true ]; then
    if [ -z "$SIGN_IDENTITY" ]; then
        echo "✗ Cannot notarize without signing"
        exit 1
    fi

    if [ -z "$TEAM_ID" ]; then
        echo "✗ --team-id is required for notarization"
        exit 1
    fi

    # Get app-specific password from keychain if not provided
    if [ -z "$APP_SPECIFIC_PASSWORD" ]; then
        APP_SPECIFIC_PASSWORD=$(security find-generic-password \
            -a "$TEAM_ID" -s "notarytool" -w 2>/dev/null || echo "")
        if [ -z "$APP_SPECIFIC_PASSWORD" ]; then
            echo "✗ App-specific password not found in keychain."
            echo "  Store it with:"
            echo "  security add-generic-password -a <team-id> -s notarytool -w <password>"
            exit 1
        fi
    fi

    echo "▸ Notarizing…"

    xcrun notarytool submit "$DMG_PATH" \
        --team-id "$TEAM_ID" \
        --apple-id "$TEAM_ID" \
        --password "$APP_SPECIFIC_PASSWORD" \
        --wait

    # Staple the notarization ticket
    xcrun stapler staple "$APP_BUNDLE"

    echo "✓ Notarization complete"

    # Re-create DMG with stapled app
    rm -f "$DMG_PATH"
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$APP_BUNDLE" \
        -ov -format UDZO \
        "$DMG_PATH"

    echo "✓ Final DMG: $DMG_PATH"
fi

echo ""
echo "══════════════════════════════════════════"
echo "  Package complete!"
echo "  App:  $APP_BUNDLE"
echo "  DMG:  $DMG_PATH"
echo "══════════════════════════════════════════"

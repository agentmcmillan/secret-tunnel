#!/bin/bash
set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <dmg-path> <keychain-profile>"
    echo ""
    echo "First-time setup:"
    echo "  xcrun notarytool store-credentials <profile-name> \\"
    echo "    --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID"
    exit 1
fi

DMG_PATH="$1"
PROFILE="$2"

if [ ! -f "$DMG_PATH" ]; then
    echo "Error: DMG not found at $DMG_PATH"
    exit 1
fi

echo "Submitting $DMG_PATH for notarization..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$PROFILE" \
    --wait

echo ""
echo "Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

echo ""
echo "Validating..."
xcrun stapler validate "$DMG_PATH"

echo ""
echo "Verifying with Gatekeeper..."
spctl -a -v "$DMG_PATH" 2>&1 || true

echo ""
echo "Notarization complete: $DMG_PATH"

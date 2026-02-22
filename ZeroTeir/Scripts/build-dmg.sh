#!/bin/bash
set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <app-path> <output-dmg>"
    exit 1
fi

APP_PATH="$1"
OUTPUT_DMG="$2"
TEMP_DMG="${OUTPUT_DMG%.dmg}-temp.dmg"
VOLUME_NAME="ZeroTeir"
MOUNT_POINT="/Volumes/${VOLUME_NAME}"

# Cleanup on exit
cleanup() {
    if [ -d "${MOUNT_POINT}" ]; then
        hdiutil detach "${MOUNT_POINT}" -quiet || true
    fi
    rm -f "${TEMP_DMG}"
}
trap cleanup EXIT

# Remove existing DMG
rm -f "${OUTPUT_DMG}"

# Create temporary DMG
echo "Creating temporary DMG..."
hdiutil create -size 100m -fs HFS+ -volname "${VOLUME_NAME}" "${TEMP_DMG}"

# Mount the DMG
echo "Mounting DMG..."
hdiutil attach "${TEMP_DMG}" -mountpoint "${MOUNT_POINT}"

# Copy app
echo "Copying application..."
cp -R "${APP_PATH}" "${MOUNT_POINT}/"

# Create Applications symlink
echo "Creating Applications symlink..."
ln -s /Applications "${MOUNT_POINT}/Applications"

# Set icon positions and window properties
echo "Setting Finder view options..."
cat > "${MOUNT_POINT}/.DS_Store_template" <<EOF
# This would contain Finder view settings
# For now, using defaults
EOF

# Unmount
echo "Unmounting DMG..."
hdiutil detach "${MOUNT_POINT}"

# Convert to compressed, read-only
echo "Converting to final DMG..."
hdiutil convert "${TEMP_DMG}" -format UDZO -o "${OUTPUT_DMG}"

echo "DMG created successfully: ${OUTPUT_DMG}"

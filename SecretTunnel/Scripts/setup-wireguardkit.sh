#!/bin/bash
set -e

echo "==================================="
echo "WireGuardKit Setup Instructions"
echo "==================================="
echo ""
echo "Due to XcodeGen limitations with Swift Package Manager,"
echo "you need to manually add WireGuardKit in Xcode."
echo ""
echo "Steps:"
echo "1. Open SecretTunnel.xcodeproj in Xcode"
echo "2. Select the project in the navigator"
echo "3. Go to the 'Package Dependencies' tab"
echo "4. Click the '+' button"
echo "5. Enter repository URL: https://github.com/WireGuard/wireguard-apple"
echo "6. Select 'Branch: master'"
echo "7. Click 'Add Package'"
echo "8. Select 'WireGuardKit' and add it to 'SecretTunnelExtension' target"
echo "9. Build the project (Cmd+B)"
echo ""
echo "Opening Xcode now..."
echo ""

# Open Xcode with the project
open SecretTunnel.xcodeproj

echo "After adding the package dependency in Xcode, you can build from command line:"
echo "  make build"
echo ""

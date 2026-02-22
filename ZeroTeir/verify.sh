#!/bin/bash

echo "======================================"
echo "ZeroTeir Build Verification"
echo "======================================"
echo ""

ERRORS=0

# Check Swift version
echo "1. Checking Swift installation..."
if command -v swift &> /dev/null; then
    echo "   ✓ Swift found"
    swift --version | head -n 1
else
    echo "   ✗ Swift not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check file structure
echo "2. Verifying file structure..."
REQUIRED_FILES=(
    "Package.swift"
    "Sources/ZeroTeir/App/ZeroTeirApp.swift"
    "Sources/ZeroTeir/App/AppDelegate.swift"
    "Sources/ZeroTeir/Views/MenuBarView.swift"
    "Sources/ZeroTeir/Views/SettingsView.swift"
    "Sources/ZeroTeir/Views/StatusView.swift"
    "Sources/ZeroTeir/Views/OnboardingView.swift"
    "Sources/ZeroTeir/Models/ConnectionState.swift"
    "Sources/ZeroTeir/Models/InstanceInfo.swift"
    "Sources/ZeroTeir/Models/WireGuardConfig.swift"
    "Sources/ZeroTeir/Models/ConnectionStatus.swift"
    "Sources/ZeroTeir/Services/InstanceManager.swift"
    "Sources/ZeroTeir/Services/HeadscaleClient.swift"
    "Sources/ZeroTeir/Services/TunnelManager.swift"
    "Sources/ZeroTeir/Services/ConnectionService.swift"
    "Sources/ZeroTeir/Services/NetworkMonitor.swift"
    "Sources/ZeroTeir/Services/KeychainService.swift"
    "Sources/ZeroTeir/State/AppState.swift"
    "Sources/ZeroTeir/Utilities/Constants.swift"
    "Sources/ZeroTeir/Utilities/Logger.swift"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✓ $file"
    else
        echo "   ✗ $file (missing)"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# Check WireGuard tools
echo "3. Checking WireGuard tools..."
if command -v wg &> /dev/null; then
    echo "   ✓ wg found at $(which wg)"
else
    echo "   ⚠ wg not found (install: brew install wireguard-tools)"
fi

if command -v wg-quick &> /dev/null; then
    echo "   ✓ wg-quick found at $(which wg-quick)"
else
    echo "   ⚠ wg-quick not found (install: brew install wireguard-tools)"
fi
echo ""

# Try to build
echo "4. Attempting build..."
if swift build -c release 2>&1 | tee build.log | tail -20; then
    echo ""
    echo "   ✓ Build successful"

    if [ -f ".build/release/ZeroTeir" ]; then
        echo "   ✓ Executable created"
        SIZE=$(du -h .build/release/ZeroTeir | cut -f1)
        echo "   Size: $SIZE"
    else
        echo "   ✗ Executable not found"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo ""
    echo "   ✗ Build failed"
    echo "   See build.log for details"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Summary
echo "======================================"
if [ $ERRORS -eq 0 ]; then
    echo "✓ Verification passed!"
    echo ""
    echo "To run ZeroTeir:"
    echo "  ./.build/release/ZeroTeir"
    echo ""
    echo "To create app bundle:"
    echo "  make bundle"
else
    echo "✗ Verification failed with $ERRORS error(s)"
    echo ""
    echo "Please check the errors above."
fi
echo "======================================"

exit $ERRORS

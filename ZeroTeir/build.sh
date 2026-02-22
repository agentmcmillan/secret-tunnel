#!/bin/bash

set -e

echo "======================================"
echo "ZeroTeir Build Script"
echo "======================================"
echo ""

# Check for Swift
if ! command -v swift &> /dev/null; then
    echo "Error: Swift not found. Please install Xcode or Swift toolchain."
    exit 1
fi

echo "Swift version:"
swift --version
echo ""

# Check for WireGuard tools
if ! command -v wg &> /dev/null && ! command -v wg-quick &> /dev/null; then
    echo "Warning: WireGuard tools not found."
    echo "Install with: brew install wireguard-tools"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Build
echo "Building ZeroTeir..."
swift build -c release

if [ $? -eq 0 ]; then
    echo ""
    echo "======================================"
    echo "Build successful!"
    echo "======================================"
    echo ""
    echo "Executable: .build/release/ZeroTeir"
    echo ""
    echo "To run:"
    echo "  ./.build/release/ZeroTeir"
    echo ""
    echo "To create app bundle:"
    echo "  make bundle"
    echo ""
else
    echo ""
    echo "Build failed!"
    exit 1
fi

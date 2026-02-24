#!/bin/bash
# Secret Tunnel Dependency Version Checker
# Checks for latest versions of key dependencies

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Secret Tunnel Dependency Version Check"
echo "================================="
echo ""

# Check Go (required for WireGuardKit build)
echo "--- Build Tools ---"
if command -v go &>/dev/null; then
    CURRENT_GO=$(go version | awk '{print $3}' | sed 's/go//')
    LATEST_GO=$(curl -sL "https://go.dev/VERSION?m=text" | head -1 | sed 's/go//')
    if [ "$CURRENT_GO" = "$LATEST_GO" ]; then
        echo -e "${GREEN}Go: $CURRENT_GO (latest)${NC}"
    else
        echo -e "${YELLOW}Go: $CURRENT_GO -> $LATEST_GO available${NC}"
    fi
else
    echo -e "${RED}Go: NOT INSTALLED (required for WireGuardKit build)${NC}"
    echo "  Install: brew install go"
fi

# Check Xcode / xcodebuild
if command -v xcodebuild &>/dev/null; then
    XCODE_VER=$(xcodebuild -version | head -1)
    echo -e "${GREEN}$XCODE_VER${NC}"
else
    echo -e "${RED}Xcode: NOT INSTALLED${NC}"
fi

# Check XcodeGen
if command -v xcodegen &>/dev/null; then
    CURRENT_XCODEGEN=$(xcodegen version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}XcodeGen: $CURRENT_XCODEGEN${NC}"
else
    echo -e "${RED}XcodeGen: NOT INSTALLED${NC}"
    echo "  Install: brew install xcodegen"
fi

echo ""
echo "--- Project Dependencies ---"

# Check WireGuardKit (local vendored copy)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WG_PACKAGE="$PROJECT_DIR/LocalPackages/wireguard-apple/Package.swift"
if [ -f "$WG_PACKAGE" ]; then
    # Get local version from git tag or commit
    LOCAL_WG_VER="vendored (local)"
    # Check upstream latest release
    LATEST_WG=$(curl -sL "https://api.github.com/repos/WireGuard/wireguard-apple/releases/latest" 2>/dev/null | grep '"tag_name"' | sed 's/.*: "\(.*\)".*/\1/' || echo "unknown")
    if [ "$LATEST_WG" != "unknown" ] && [ -n "$LATEST_WG" ]; then
        echo -e "${YELLOW}WireGuardKit: $LOCAL_WG_VER (upstream latest: $LATEST_WG)${NC}"
    else
        echo -e "${GREEN}WireGuardKit: $LOCAL_WG_VER${NC}"
    fi
else
    echo -e "${RED}WireGuardKit: NOT FOUND at $WG_PACKAGE${NC}"
fi

# Check Headscale version in Terraform
TF_DIR="$(dirname "$PROJECT_DIR")/terraform"
if [ -f "$TF_DIR/variables.tf" ]; then
    CURRENT_HS=$(grep -A3 'variable "headscale_version"' "$TF_DIR/variables.tf" | grep 'default' | sed 's/.*"\(.*\)".*/\1/')
    LATEST_HS=$(curl -sL "https://api.github.com/repos/juanfont/headscale/releases/latest" 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/' || echo "unknown")
    if [ "$CURRENT_HS" = "$LATEST_HS" ]; then
        echo -e "${GREEN}Headscale: $CURRENT_HS (latest)${NC}"
    elif [ "$LATEST_HS" != "unknown" ] && [ -n "$LATEST_HS" ]; then
        echo -e "${YELLOW}Headscale: $CURRENT_HS -> $LATEST_HS available${NC}"
        echo "  Update in: terraform/variables.tf (headscale_version)"
    else
        echo -e "${GREEN}Headscale: $CURRENT_HS (couldn't check latest)${NC}"
    fi
else
    echo -e "${YELLOW}Headscale: terraform/variables.tf not found${NC}"
fi

echo ""
echo "--- Terraform ---"

# Check Terraform
if command -v terraform &>/dev/null; then
    CURRENT_TF=$(terraform version -json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['terraform_version'])" 2>/dev/null || terraform version | head -1 | awk '{print $2}' | sed 's/v//')
    echo -e "${GREEN}Terraform: $CURRENT_TF${NC}"
else
    echo -e "${YELLOW}Terraform: NOT INSTALLED (only needed for infrastructure deployment)${NC}"
    echo "  Install: brew install terraform"
fi

# Check AWS CLI
if command -v aws &>/dev/null; then
    AWS_VER=$(aws --version 2>/dev/null | awk '{print $1}' | sed 's|aws-cli/||')
    echo -e "${GREEN}AWS CLI: $AWS_VER${NC}"
else
    echo -e "${YELLOW}AWS CLI: NOT INSTALLED (only needed for infrastructure deployment)${NC}"
fi

echo ""
echo "--- libwg-go (WireGuard Go bridge) ---"
LIBWG="$PROJECT_DIR/LocalPackages/wireguard-apple/Sources/WireGuardKitGo/libwg-go.a"
if [ -f "$LIBWG" ]; then
    ARCH=$(lipo -info "$LIBWG" 2>/dev/null | awk -F': ' '{print $NF}' || echo "unknown")
    SIZE=$(du -h "$LIBWG" | awk '{print $1}')
    echo -e "${GREEN}libwg-go.a: $SIZE ($ARCH)${NC}"
else
    echo -e "${RED}libwg-go.a: NOT BUILT${NC}"
    echo "  Build: cd LocalPackages/wireguard-apple/Sources/WireGuardKitGo && make ARCHS=arm64 PLATFORM_NAME=macosx"
fi

echo ""
echo "Done."

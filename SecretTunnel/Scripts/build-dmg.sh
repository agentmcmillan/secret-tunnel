#!/bin/bash
set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <app-path> <output-dmg>"
    exit 1
fi

APP_PATH="$1"
OUTPUT_DMG="$2"
TEMP_DMG="${OUTPUT_DMG%.dmg}-temp.dmg"
VOLUME_NAME="Secret Tunnel"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Use a unique mount point to avoid conflicts with stale mounts
MOUNT_POINT=$(mktemp -d /tmp/dmg-mount.XXXXXX)

# Validate app bundle exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: App bundle not found at $APP_PATH"
    exit 1
fi

# Cleanup on exit
cleanup() {
    hdiutil detach "${MOUNT_POINT}" -quiet -force 2>/dev/null || true
    rmdir "${MOUNT_POINT}" 2>/dev/null || true
    rm -f "${TEMP_DMG}"
}
trap cleanup EXIT

# Remove existing DMG
rm -f "${OUTPUT_DMG}"

# Create temporary DMG
echo "Creating temporary DMG..."
hdiutil create -size 120m -fs HFS+ -volname "${VOLUME_NAME}" "${TEMP_DMG}"

# Mount the DMG
echo "Mounting DMG..."
hdiutil attach "${TEMP_DMG}" -mountpoint "${MOUNT_POINT}"

# Copy app
echo "Copying application..."
cp -R "${APP_PATH}" "${MOUNT_POINT}/"

# Create Applications symlink
echo "Creating Applications symlink..."
ln -sf /Applications "${MOUNT_POINT}/Applications"

# Copy setup script and terraform
echo "Adding setup files..."
cp "${PROJECT_ROOT}/setup.sh" "${MOUNT_POINT}/setup.sh"
# Copy terraform source files (exclude .terraform cache, state files, tfvars)
mkdir -p "${MOUNT_POINT}/terraform"
rsync -a \
    --exclude='.terraform' \
    --exclude='*.tfstate*' \
    --exclude='terraform.tfvars' \
    "${PROJECT_ROOT}/terraform/" "${MOUNT_POINT}/terraform/"

# Generate README
cat > "${MOUNT_POINT}/README.txt" <<'READMEEOF'
Secret Tunnel - VPN On Demand
=============================

INSTALLATION
  1. Drag SecretTunnel.app to the Applications folder
  2. Open Secret Tunnel from your Applications or Spotlight

INFRASTRUCTURE SETUP (first time only)
  You need an AWS account with IAM access keys (not a login/password).
  To create them: AWS Console → IAM → Users → Create access key
  Then configure locally:
    aws configure --profile zeroteir
    # Enter your Access Key ID and Secret Access Key when prompted

  Option A — Automated:
    Open Terminal and run:
      /Volumes/Secret\ Tunnel/setup.sh --profile zeroteir

    This will:
      - Create an SSH key pair
      - Generate terraform.tfvars
      - Deploy all AWS resources (EC2, Lambda, API Gateway, Headscale)
      - Wait for Headscale to bootstrap
      - Print the settings to enter in the app

  Option B — Manual:
    1. export AWS_PROFILE=zeroteir
    2. cd /Volumes/Secret\ Tunnel/terraform
    3. Copy terraform.tfvars.example to terraform.tfvars and edit
    4. terraform init && terraform apply
    5. Note the outputs: api_endpoint, api_key, headscale_url
    6. Get the Headscale API key:
       aws ssm get-parameter --name /secrettunnel/headscale-api-key \
           --with-decryption --query Parameter.Value --output text

APP CONFIGURATION
  1. Click the Secret Tunnel menu bar icon → Settings
  2. Enter:
     - Lambda API Endpoint  (from terraform output)
     - Lambda API Key       (terraform output -raw api_key)
     - Headscale URL        (https://<elastic-ip>)
     - Headscale API Key    (from SSM, see above)
  3. Click Connect!

ESTIMATED COST
  Persistent:  ~$4.30/mo  (Elastic IP + 8GB EBS)
  Compute:     ~$0.01/hr  (t3.micro, only while connected)
  The instance auto-stops after 60 minutes of idle.

REQUIREMENTS
  - macOS 14.0+ (Apple Silicon)
  - AWS CLI + Terraform (for infrastructure setup)
  - AWS account with IAM credentials

MORE INFO
  Source: https://github.com/conor/zeroteir (or your Gitea instance)
READMEEOF

# Unmount (retry with force if busy)
echo "Unmounting DMG..."
sync
sleep 1
hdiutil detach "${MOUNT_POINT}" 2>/dev/null || {
    echo "Retrying unmount with force..."
    sleep 2
    hdiutil detach "${MOUNT_POINT}" -force
}

# Convert to compressed, read-only
echo "Converting to final DMG..."
hdiutil convert "${TEMP_DMG}" -format UDZO -o "${OUTPUT_DMG}"

echo "DMG created successfully: ${OUTPUT_DMG}"

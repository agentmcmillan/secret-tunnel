# Secret Tunnel - VPN on Demand

Self-hosted, cost-optimized VPN solution with macOS menu bar app and AWS infrastructure.

Named after Chong's song from Avatar: The Last Airbender's "Cave of Two Lovers".

**Status**: v0.2.0 - Feature Complete

---

## Quick Overview

Secret Tunnel provides one-click VPN connectivity through a macOS menu bar app that manages on-demand AWS infrastructure. The VPN server only runs when you need it, minimizing costs to ~$5-15/month.

**Key Features**:
- One-click connect/disconnect from macOS menu bar
- Self-hosted (full control, no third-party logging)
- Cost-optimized (instance auto-stops when idle)
- Fast (WireGuard protocol)
- Kill switch (block internet if VPN drops)
- Auto-connect on untrusted WiFi networks
- Split tunnel support (home LAN + internet via AWS)
- Launch at login support

---

## Architecture

```
macOS Menu Bar App (Swift/SwiftUI)
        |
        |  HTTPS (Lambda API) + WireGuard (UDP 51820)
        v
AWS Infrastructure (Terraform)
  - Lambda + API Gateway (start/stop/status)
  - EC2 Instance (on-demand, t3.micro)
    - Headscale (control plane)
    - WireGuard (data plane)
  - CloudWatch (monitoring, auto-stop, dashboard)
```

**Technology Stack**:
- **VPN**: WireGuard via NetworkExtension (NEPacketTunnelProvider)
- **Control Plane**: Headscale (self-hosted Tailscale)
- **Infrastructure**: Terraform (AWS EC2, Lambda, API Gateway, CloudWatch)
- **Client**: Swift + SwiftUI + WireGuardKit (native macOS)
- **Build**: XcodeGen + Make

---

## Quick Start

### 1. Deploy AWS Infrastructure

```bash
# One-command setup (interactive)
./setup.sh

# Or manually:
cd terraform/
cp terraform.tfvars.example terraform.tfvars  # Edit with your values
terraform init && terraform apply

# Get configuration values
terraform output
terraform output -raw api_key
```

**Prerequisites**:
- AWS account with IAM access keys (create at AWS Console > IAM > Users > Security Credentials)
- AWS CLI configured: `aws configure --profile zeroteir`
- Terraform >= 1.0 (`brew install hashicorp/tap/terraform`)

### 2. Build the macOS App

```bash
cd SecretTunnel/
make build    # Build debug
make dmg      # Package as DMG
```

**Prerequisites**:
- Xcode >= 15
- macOS 14+ (Sonoma)

### 3. Configure & Connect

1. Open Secret Tunnel from menu bar
2. Enter settings from `terraform output`:
   - API Endpoint
   - API Key
   - Headscale URL
3. Click **Connect**

---

## Cost Estimate

| Usage | Instance Hours | Monthly Cost |
|-------|---------------|-------------|
| **Idle** (VPN off) | 0 hrs | ~$4.30 |
| **Light** (2 hrs/day) | 60 hrs | ~$5.00 |
| **Medium** (4 hrs/day) | 120 hrs | ~$5.55 |
| **Heavy** (8 hrs/day) | 240 hrs | ~$6.80 |

Persistent costs: Elastic IP ($3.65/mo) + EBS 8GB ($0.64/mo) = $4.29/mo minimum.

---

## Project Structure

```
zeroteir/
├── SecretTunnel/              # macOS app
│   ├── Sources/SecretTunnel/  # App source
│   │   ├── App/               # Entry point, delegate
│   │   ├── Views/             # SwiftUI (MenuBar, Settings, Onboarding)
│   │   ├── Services/          # Business logic (Tunnel, Instance, Headscale)
│   │   ├── Models/            # Data models
│   │   └── Utilities/         # Constants, Logger
│   ├── SecretTunnelExtension/ # NetworkExtension (PacketTunnelProvider)
│   ├── Shared/                # IPC types
│   ├── Tests/                 # Unit tests (32 tests)
│   ├── LocalPackages/         # Vendored WireGuardKit
│   ├── Scripts/               # build-dmg.sh
│   ├── project.yml            # XcodeGen config
│   └── Makefile               # Build commands
├── terraform/                 # AWS infrastructure (37 resources)
│   ├── main.tf                # EC2, networking, security groups
│   ├── lambda.tf              # Lambda functions, API Gateway
│   ├── cloudwatch.tf          # Monitoring, alarms, dashboard
│   ├── iam.tf                 # IAM roles, policies
│   ├── variables.tf           # Input variables
│   ├── outputs.tf             # Output values
│   └── files/                 # Cloud-init, Lambda code
├── releases/                  # Packaged DMG builds
├── setup.sh                   # One-command infrastructure deploy
└── CLAUDE.md                  # Build & development reference
```

---

## Features

### Implemented
- [x] One-click connect/disconnect
- [x] EC2 instance lifecycle management (start/stop via Lambda)
- [x] WireGuard tunnel via NetworkExtension
- [x] Headscale auto-registration on first connect
- [x] Connection status monitoring (IP, latency, data, uptime)
- [x] Auto-reconnect on network changes
- [x] Auto-stop idle instance (configurable timeout)
- [x] Kill switch (block non-VPN traffic)
- [x] Auto-connect on untrusted WiFi
- [x] Split tunnel (home LAN via NAS + internet via AWS)
- [x] Launch at login
- [x] Keychain credential storage
- [x] CloudWatch dashboard & alarms
- [x] Structured logging (OSLog)
- [x] Unit tests (32 passing)

### Future Roadmap
- [ ] Developer ID signing & notarization
- [ ] Stealth Mode (stunnel/shadowsocks for TCP 443)
- [ ] Multi-region support
- [ ] Per-app split tunneling
- [ ] iOS companion app

---

## Development

```bash
cd SecretTunnel/
make build     # Debug build
make release   # Release build
make dmg       # Package DMG
make clean     # Clean build artifacts
make check     # Verify signing
```

### Running Tests
```bash
xcodebuild -project SecretTunnel.xcodeproj \
  -scheme SecretTunnelTests \
  -configuration Debug \
  -derivedDataPath build \
  test
```

---

## License

MIT

---

## Acknowledgments

- [WireGuard](https://www.wireguard.com/) - Modern VPN protocol
- [Headscale](https://github.com/juanfont/headscale) - Self-hosted Tailscale control plane
- [WireGuardKit](https://github.com/WireGuard/wireguard-apple) - Swift WireGuard library

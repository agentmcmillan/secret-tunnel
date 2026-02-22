# ZeroTeir - VPN on Demand

Self-hosted, cost-optimized VPN solution with macOS menu bar app and AWS infrastructure.

**Status**: Planning Complete | Ready for Development

---

## Quick Overview

ZeroTeir provides one-click VPN connectivity through a macOS menu bar app that manages on-demand AWS infrastructure. The VPN server only runs when you need it, minimizing costs to ~$10/month (vs $13+ for commercial VPNs).

**Key Features**:
- One-click connect/disconnect from macOS menu bar
- Self-hosted (full control, no third-party logging)
- Cost-optimized (instance auto-stops when idle)
- Fast (WireGuard protocol, 500-1000 Mbps)
- Reliable (excellent NAT traversal via Tailscale/Headscale)

---

## Architecture

```
┌─────────────────────┐
│  macOS Menu Bar App │  (Swift + SwiftUI)
│  - Connect/Disconnect│
│  - Status Display    │
└──────────┬──────────┘
           │
           │ HTTPS (Lambda API)
           │ WireGuard (UDP 51820)
           │
┌──────────▼──────────────────────────────┐
│         AWS Infrastructure               │
│                                          │
│  ┌────────────────┐  ┌────────────────┐ │
│  │ Lambda + API   │  │ EC2 Instance   │ │
│  │ Gateway        │  │ (on-demand)    │ │
│  │ - Start/Stop   │  │                │ │
│  │   instance     │  │ - Headscale    │ │
│  └────────────────┘  │ - WireGuard    │ │
│                      │                │ │
│  ┌────────────────┐  │ - Auto-stop    │ │
│  │ CloudWatch     │  │   after 60min  │ │
│  │ - Auto-stop    │  └────────────────┘ │
│  │ - Monitoring   │                      │
│  └────────────────┘                      │
└──────────────────────────────────────────┘
```

**Technology Stack**:
- **VPN**: WireGuard (modern, fast, secure)
- **Control Plane**: Headscale (self-hosted Tailscale)
- **Infrastructure**: Terraform (AWS EC2, Lambda, API Gateway)
- **Client**: Swift + SwiftUI (native macOS)

---

## Documentation

### Planning Documents (Start Here)

1. **[RESEARCH.md](./RESEARCH.md)** - VPN solution comparison & recommendations
   - Read this first to understand why WireGuard + Headscale was chosen
   - Includes firewall bypass analysis and cost estimates

2. **[PRD.md](./PRD.md)** - Product Requirements Document
   - 19 user stories across 5 epics
   - Development roadmap (6-9 week timeline)
   - Success metrics and risk analysis

3. **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Technical Architecture
   - Detailed component diagrams
   - Code structure and data models
   - Security, performance, and cost analysis

### Discovery Documents (Brain-Wave Memory)

4. **[rem/discoveries/planning.md](./rem/discoveries/planning.md)** - Planning session insights
5. **[rem/sessions/bart-2026-02-21-initial-planning.md](./rem/sessions/bart-2026-02-21-initial-planning.md)** - Detailed session notes

---

## Cost Estimate

### Monthly Costs

| Usage Pattern | Instance Hours | Data Transfer | Total Cost |
|---------------|----------------|---------------|------------|
| **Light** (2 hrs/day) | 60 hrs | 10 GB | $5.12/mo |
| **Medium** (4 hrs/day) | 120 hrs | 50 GB | $9.35/mo |
| **Heavy** (8 hrs/day) | 240 hrs | 100 GB | $15.10/mo |

**Comparison**:
- NordVPN: $12.99/month
- ExpressVPN: $12.95/month
- ZeroTeir (self-hosted): $5-15/month (scales with usage)

**Cost Optimization**:
- Instance OFF by default (only pay $3.60/mo for Elastic IP)
- Auto-stop after 60 minutes of inactivity
- No cost when not using VPN

---

## Project Status

### Planning Phase (Complete)

- [x] Research VPN solutions (WireGuard, ZeroTier, Tailscale, etc.)
- [x] Analyze firewall bypass techniques
- [x] Design three-tier architecture
- [x] Create 19 user stories with story points
- [x] Document technical specifications
- [x] Estimate costs and timeline

### Next Steps (Development)

**Ready to Start**: User Stories (MVP - 66 story points)
- [ ] US-001: Terraform infrastructure (5 pts) - P0
- [ ] US-002: EC2 auto-configuration (8 pts) - P0
- [ ] US-003: Lambda instance control API (8 pts) - P0
- [ ] US-005: Menu bar UI shell (5 pts) - P0
- [ ] US-006: Settings UI (8 pts) - P0
- [ ] US-007: AWS instance management (8 pts) - P0
- [ ] US-008: Headscale client registration (8 pts) - P0
- [ ] US-009: WireGuard tunnel management (13 pts) - P0
- [ ] US-010: Full connect flow (13 pts) - P0
- [ ] US-011: Full disconnect flow (5 pts) - P0

**Timeline**: 4-6 weeks for working MVP

---

## Prerequisites

Before development begins, you'll need:

1. **AWS Account**
   - Billing enabled
   - IAM user with permissions: EC2, Lambda, API Gateway, CloudWatch
   - AWS CLI configured (`aws configure`)

2. **Development Tools**
   - Terraform >= 1.0
   - Xcode >= 15 (for macOS app)
   - macOS 13+ (Ventura or later)

3. **Optional**
   - Apple Developer ID (for code signing, $99/year)
   - Domain name (for Let's Encrypt SSL, optional)

---

## Quick Start (When Ready for Development)

### 1. Set Up AWS Infrastructure

```bash
cd terraform/
terraform init
terraform plan
terraform apply

# Copy outputs (Elastic IP, API endpoint, API key)
terraform output
```

### 2. Configure macOS App

```bash
cd macos-app/
open ZeroTeir.xcodeproj

# Build and run
# Enter Terraform outputs in Settings:
# - Lambda API Endpoint
# - Lambda API Key
# - Headscale Server URL
```

### 3. Connect to VPN

1. Click ZeroTeir icon in menu bar
2. Click "Connect"
3. Wait 40-75 seconds for instance to start and VPN to establish
4. Browse securely!

---

## User Stories & Development Roadmap

### Epic 1: AWS Infrastructure (4 stories, 21 points)

- **US-001** (5 pts, P0): Terraform infrastructure configuration
- **US-002** (8 pts, P0): EC2 auto-configuration via cloud-init
- **US-003** (8 pts, P0): Lambda instance control API
- **US-004** (5 pts, P1): Auto-stop idle instance (cost optimization)

### Epic 2: macOS Menu Bar App (8 stories, 65 points)

- **US-005** (5 pts, P0): Menu bar UI shell
- **US-006** (8 pts, P0): Settings UI & Keychain storage
- **US-007** (8 pts, P0): Instance management service
- **US-008** (8 pts, P0): Headscale client registration
- **US-009** (13 pts, P0): WireGuard tunnel management
- **US-010** (13 pts, P0): Full connect flow
- **US-011** (5 pts, P0): Full disconnect flow
- **US-012** (8 pts, P1): Connection status monitoring

### Epic 3: Developer Experience (3 stories, 10 points)

- **US-013** (3 pts, P1): Setup documentation
- **US-014** (2 pts, P0): Terraform output values
- **US-015** (5 pts, P1): Code signing & distribution

### Epic 4: Testing (2 stories, 16 points)

- **US-016** (13 pts, P2): Integration tests
- **US-017** (3 pts, P1): Manual test plan

### Epic 5: Observability (2 stories, 13 points)

- **US-018** (5 pts, P1): Application logging
- **US-019** (8 pts, P2): CloudWatch metrics

**Total**: 19 stories, 108 story points

---

## Technical Highlights

### Connection Flow (40-75 seconds)

```
User clicks "Connect"
  ↓
Start EC2 instance (30-60s)
  ↓
Wait for Headscale ready (5-10s)
  ↓
Retrieve WireGuard config (1s)
  ↓
Establish WireGuard tunnel (1-3s)
  ↓
Connected!
```

### Performance Metrics

- **Throughput**: 500-1000 Mbps (WireGuard on t3.micro)
- **Latency**: +20-50ms over direct connection
- **Connection Success Rate**: >95% target
- **Reliability**: >99% uptime target

### Security

- **Encryption**: WireGuard (ChaCha20-Poly1305), TLS 1.3 (HTTPS)
- **Authentication**: Multi-layer (API key, Bearer token, key pairs)
- **Secrets**: All stored in macOS Keychain (never plain text)
- **Network**: Minimal security group rules, fail2ban protection

---

## Future Roadmap (Post-MVP)

### Phase 2: Stealth Mode (2-3 weeks)
- Add stunnel/shadowsocks wrapper for TCP 443
- "Stealth Mode" toggle in UI
- Works through restrictive corporate firewalls

### Phase 3: Multi-Region (1 week)
- Deploy to multiple AWS regions
- Region selector in UI
- Auto-failover on connection failure

### Phase 4: Advanced Features (2+ weeks)
- Split tunneling (route only specific apps)
- Kill switch (block internet if VPN drops)
- Auto-connect on untrusted WiFi
- iOS companion app

---

## Contributing

This is a personal project, but contributions are welcome!

**Before submitting PR**:
1. Read [PRD.md](./PRD.md) for user story context
2. Follow existing code patterns (see [ARCHITECTURE.md](./ARCHITECTURE.md))
3. Add tests for new functionality
4. Update documentation

---

## License

TBD (To be determined by project owner)

---

## Support & Contact

**Documentation**:
- Technical questions: See [ARCHITECTURE.md](./ARCHITECTURE.md)
- Setup issues: See [PRD.md](./PRD.md) User Stories
- Research: See [RESEARCH.md](./RESEARCH.md)

**Troubleshooting**:
- Connection failures: Check CloudWatch logs
- Instance won't start: Check Lambda function logs
- macOS app crashes: Check Console.app logs

---

## Project Structure (Planned)

```
zeroteir/
├── README.md                   # This file
├── RESEARCH.md                 # VPN research findings
├── PRD.md                      # Product requirements
├── ARCHITECTURE.md             # Technical architecture
│
├── terraform/                  # AWS infrastructure
│   ├── main.tf                 # EC2, networking, security groups
│   ├── lambda.tf               # Lambda functions, API Gateway
│   ├── cloudwatch.tf           # Monitoring, alarms
│   ├── iam.tf                  # IAM roles, policies
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   └── files/
│       ├── cloud-init.yaml     # EC2 bootstrap script
│       ├── lambda_instance_control.py
│       └── lambda_idle_monitor.py
│
├── macos-app/                  # macOS menu bar app
│   ├── ZeroTeir.xcodeproj      # Xcode project
│   └── ZeroTeir/
│       ├── Sources/
│       │   ├── App.swift       # App entry point
│       │   ├── Views/          # SwiftUI views
│       │   ├── Services/       # Business logic
│       │   └── Models/         # Data models
│       └── Resources/          # Assets, icons
│
├── docs/                       # Additional documentation
│   ├── SETUP.md                # Detailed setup guide
│   └── TROUBLESHOOTING.md      # Common issues
│
└── rem/                        # Brain-Wave memory system
    ├── discoveries/            # Planning insights
    └── sessions/               # Session history
```

---

## Acknowledgments

**Technologies Used**:
- [WireGuard](https://www.wireguard.com/) - Modern VPN protocol
- [Headscale](https://github.com/juanfont/headscale) - Self-hosted Tailscale control plane
- [Terraform](https://www.terraform.io/) - Infrastructure as Code
- [AWS](https://aws.amazon.com/) - Cloud infrastructure
- [WireGuardKit](https://github.com/WireGuard/wireguard-apple) - Swift WireGuard library

**Inspired By**:
- Tailscale's excellent NAT traversal
- ZeroTier's planetary network concept
- Outline VPN's censorship resistance

---

**Last Updated**: 2026-02-21
**Status**: Planning Complete, Ready for Development
**Estimated MVP Timeline**: 4-6 weeks


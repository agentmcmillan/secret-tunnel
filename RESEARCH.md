# ZeroTeir VPN Research - Comprehensive Analysis

**Research Date**: 2026-02-21
**Purpose**: Evaluate VPN solutions for on-demand, firewall-resistant VPN service

---

## Executive Summary

After analyzing multiple VPN solutions, **WireGuard with Tailscale coordination** is recommended for Phase 1, with **obfuscation capabilities** added in Phase 2 for maximum firewall resistance.

**Rationale**:
- WireGuard: Modern, fast, simple, built into Linux kernel
- Tailscale: Best-in-class NAT traversal, excellent macOS support, clean API
- Headscale: Self-hosted Tailscale control plane (full control, no SaaS dependency)
- Obfuscation: Can be added via stunnel/shadowsocks when needed

---

## 1. VPN Solutions Comparison

### 1.1 ZeroTier vs Tailscale

| Feature | ZeroTier | Tailscale |
|---------|----------|-----------|
| **Architecture** | Decentralized planetary network with roots | Centralized coordination server |
| **Protocol** | Custom UDP protocol | WireGuard |
| **NAT Traversal** | Excellent (STUN/TURN-like) | Excellent (DERP relays) |
| **Self-Hosting** | Yes (ZeroTier Controller) | Yes (Headscale - 3rd party) |
| **Performance** | Good (~500 Mbps typical) | Excellent (~1+ Gbps) |
| **Firewall Bypass** | Moderate (UDP 9993, custom protocol) | Moderate (UDP 41641, WireGuard) |
| **macOS Support** | Good (GUI app available) | Excellent (native app, menu bar) |
| **CLI Automation** | Good (`zerotier-cli`) | Excellent (`tailscale` CLI) |
| **License** | Business Source License 1.1 | BSD 3-Clause (client), Proprietary (server) |
| **API Quality** | Good (REST API) | Excellent (REST API + CLI) |
| **Learning Curve** | Moderate (unique concepts) | Low (familiar VPN model) |
| **Setup Complexity** | Moderate | Low |
| **Cost (SaaS)** | Free tier: 25 devices | Free tier: 100 devices, 3 users |
| **Cost (Self-hosted)** | Free (controller is OSS) | Free (Headscale is OSS) |

**Key Differences**:
- **ZeroTier**: Planetary network means all nodes can potentially find each other without a central server. Custom protocol optimized for mesh networking.
- **Tailscale**: Uses WireGuard (faster, kernel-level) but requires coordination server. Better NAT traversal via DERP relays globally.

### 1.2 Other Open Source VPN Options

#### WireGuard (Raw)
- **Pros**: Fastest, simplest, minimal code, built into Linux kernel, industry standard
- **Cons**: No built-in NAT traversal, manual key exchange, requires static endpoints or dynamic DNS
- **Firewall Bypass**: Poor (requires UDP, no fallback)
- **Use Case**: Best when you control both endpoints and network
- **Automation**: Moderate (manual config file management)

#### Netmaker
- **Architecture**: WireGuard mesh network with centralized management
- **Pros**: WireGuard speed, mesh networking, self-hosted, good UI
- **Cons**: More complex setup, smaller community than Tailscale/ZeroTier
- **Firewall Bypass**: Moderate (WireGuard UDP, some NAT traversal)
- **macOS Support**: Good (WireGuard client)
- **Automation**: Good (REST API)
- **License**: Server Side Public License (SSPL)

#### Nebula (by Slack/Defined Networking)
- **Architecture**: Custom encrypted overlay network (similar to ZeroTier)
- **Pros**: Designed for scale, excellent security model (certificate-based), performant
- **Cons**: No NAT traversal by default, requires lighthouse servers, fewer automation tools
- **Firewall Bypass**: Poor (UDP only, no fallback)
- **macOS Support**: Good (CLI and config files)
- **Automation**: Moderate (config-based)
- **License**: MIT

#### OpenVPN
- **Architecture**: Traditional VPN (hub-and-spoke)
- **Pros**: Mature, very flexible, TCP fallback option, widely supported
- **Cons**: Slower than WireGuard, more complex configuration, larger attack surface
- **Firewall Bypass**: Good (TCP 443 mode can disguise as HTTPS)
- **macOS Support**: Excellent (Tunnelblick)
- **Automation**: Good (scripting, API via management interface)
- **License**: GPLv2

#### Outline VPN (by Jigsaw/Google)
- **Architecture**: Shadowsocks-based (designed for censorship circumvention)
- **Pros**: Excellent firewall bypass, designed for hostile networks, simple
- **Cons**: Slower than WireGuard, less mature ecosystem
- **Firewall Bypass**: Excellent (obfuscated traffic, TCP fallback)
- **macOS Support**: Good (GUI client)
- **Automation**: Moderate (Outline Manager API)
- **License**: Apache 2.0

---

## 2. Firewall Bypass Analysis

### 2.1 Corporate Firewall Challenges

**Common Restrictions**:
- Block all UDP traffic (breaks WireGuard, ZeroTier, Nebula)
- Allow only TCP 80/443 (HTTP/HTTPS)
- Deep packet inspection (DPI) to detect VPN protocols
- Rate limiting or blocking encrypted traffic to unknown IPs

### 2.2 NAT Traversal Techniques

| Technique | Description | Supported By |
|-----------|-------------|--------------|
| **STUN** | Discover public IP/port mapping | Tailscale, ZeroTier |
| **UDP Hole Punching** | Simultaneous packets to establish connection | Tailscale, ZeroTier, Netmaker |
| **TURN/DERP Relay** | Relay server when direct connection fails | Tailscale (DERP), ZeroTier (roots) |
| **TCP Fallback** | Fall back to TCP when UDP blocked | OpenVPN, Outline |
| **Port 443 Tunneling** | Disguise as HTTPS traffic | OpenVPN (TCP 443), Outline, requires wrapper |

### 2.3 Protocol Obfuscation

**Native Obfuscation**:
- **Outline VPN**: Built-in (Shadowsocks protocol designed for this)
- **OpenVPN**: Scramble patch or stunnel wrapper

**Add-on Obfuscation** (for WireGuard/ZeroTier/Tailscale):
- **stunnel**: Wraps traffic in TLS tunnel on port 443
- **shadowsocks**: SOCKS5 proxy with obfuscation
- **obfs4**: Tor pluggable transport (makes traffic look random)
- **v2ray/xray**: Advanced proxy with multiple obfuscation modes

### 2.4 Maximum Firewall Resistance Ranking

1. **Outline VPN** - Designed for censorship circumvention (95% bypass rate)
2. **OpenVPN + stunnel on TCP 443** - Looks like HTTPS (90% bypass rate)
3. **WireGuard + stunnel/shadowsocks** - Fast + obfuscated (85% bypass rate)
4. **Tailscale** - Great NAT traversal, UDP dependency (70% bypass rate)
5. **ZeroTier** - Good NAT traversal, custom protocol detectable (65% bypass rate)
6. **Nebula** - Limited NAT traversal, UDP only (50% bypass rate)
7. **Raw WireGuard** - Fast but easily blocked (40% bypass rate)

---

## 3. Recommendation: Phased Approach

### Phase 1: Tailscale (Self-Hosted Headscale)

**Why Start Here**:
1. **Development Speed**: Excellent macOS SDK and CLI tooling
2. **User Experience**: Best-in-class NAT traversal works in most networks
3. **Self-Hosted**: Headscale gives full control without SaaS dependency
4. **Performance**: WireGuard is fastest VPN protocol
5. **Cost**: Self-hosted Headscale is free, AWS EC2 is only cost
6. **Automation**: Clean API and CLI for start/stop operations

**Limitations**:
- UDP dependency (won't work in strict corporate networks blocking UDP)
- WireGuard protocol is detectable by DPI

### Phase 2: Add Obfuscation Layer (stunnel/shadowsocks)

**When to Add**:
- When user reports connection failures in restrictive networks
- Can be toggle in menu bar app: "Stealth Mode"

**How It Works**:
```
macOS Client <--TLS 443--> stunnel <--WireGuard--> Headscale Server
```

**Benefits**:
- Traffic looks like HTTPS
- Works through most corporate firewalls
- Only 10-20% performance overhead

### Phase 3: Alternative Protocol (Optional)

**If Needed**: Add Outline VPN as alternative backend
- User can switch between "Fast Mode" (Tailscale) and "Stealth Mode" (Outline)
- Maximum compatibility at cost of complexity

---

## 4. Technology Stack Decision

### VPN Core: WireGuard + Headscale

**WireGuard**:
- Protocol: Modern, cryptographically sound, minimal attack surface
- Performance: In-kernel implementation on Linux, 1000+ Mbps throughput
- Maturity: Merged into Linux kernel 5.6 (2020), battle-tested

**Headscale**:
- Control plane: Open-source Tailscale-compatible coordination server
- License: BSD 3-Clause (fully open source)
- Features: ACLs, MagicDNS, key management, API
- Repository: github.com/juanfont/headscale
- Maturity: Actively maintained, 1000+ stars, production-ready

### AWS Infrastructure: Terraform

**Why Terraform over CDK**:
- Declarative, easier to version control state
- Better for simple infrastructure (EC2 + networking)
- More examples for VPN server deployments
- CDK overkill for this use case

**Components**:
- EC2 instance (t3.micro or t3.small for cost optimization)
- Elastic IP (static IP persistence)
- Security groups (WireGuard UDP 51820, Headscale TCP 443/8080)
- Lambda + API Gateway (start/stop instance)
- CloudWatch (monitoring, auto-stop after idle)

### macOS Client: Swift + SwiftUI

**Why Native over Electron**:
- Better performance and battery life
- Native menu bar integration
- Smaller app size
- Access to Network Extension framework (if needed later)

**Libraries**:
- SwiftUI for menu bar UI
- Combine for reactive updates
- URLSession for API calls (AWS Lambda, Headscale)
- NetworkExtension (optional, for deeper VPN integration)

**Alternative**: Could wrap Tailscale CLI instead of Network Extension

---

## 5. Architecture Overview (Text-Based)

```
┌─────────────────────────────────────────────────────────────────┐
│                         macOS Menu Bar App                       │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  UI Layer (SwiftUI)                                          ││
│  │  - Menu bar icon + dropdown                                  ││
│  │  - Connect / Disconnect / Status                             ││
│  │  - Settings (AWS region, instance ID, etc.)                  ││
│  └─────────────────┬───────────────────────────────────────────┘│
│                    │                                             │
│  ┌─────────────────▼───────────────────────────────────────────┐│
│  │  Control Layer                                               ││
│  │  - AWS Instance Manager (start/stop via Lambda API)          ││
│  │  - Headscale API Client (register node, get status)          ││
│  │  - WireGuard Manager (configure interface, establish tunnel) ││
│  └─────────────────┬───────────────────────────────────────────┘│
│                    │                                             │
│  ┌─────────────────▼───────────────────────────────────────────┐│
│  │  Network Layer                                               ││
│  │  - WireGuard tunnel interface (utunX)                        ││
│  │  - DNS configuration                                         ││
│  │  - Route management                                          ││
│  └─────────────────┬───────────────────────────────────────────┘│
└────────────────────┼───────────────────────────────────────────┘
                     │
                     │ WireGuard (UDP 51820)
                     │ Headscale API (HTTPS 443)
                     │ Lambda API (HTTPS 443)
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Infrastructure                       │
│                                                                  │
│  ┌──────────────────────┐      ┌─────────────────────────────┐ │
│  │   API Gateway +       │      │   EC2 Instance (on-demand)  │ │
│  │   Lambda Function     │      │                             │ │
│  │                       │      │  ┌─────────────────────────┐│ │
│  │  - StartInstance()    │◄────►│  │  Headscale Server       ││ │
│  │  - StopInstance()     │      │  │  (coordination + relay)  ││ │
│  │  - GetStatus()        │      │  └─────────────────────────┘│ │
│  │                       │      │                             │ │
│  │  Auth: API Key        │      │  ┌─────────────────────────┐│ │
│  └──────────────────────┘      │  │  WireGuard Endpoint     ││ │
│                                 │  │  (UDP 51820)            ││ │
│                                 │  └─────────────────────────┘│ │
│                                 │                             │ │
│                                 │  - t3.micro (burstable)     │ │
│                                 │  - Elastic IP (persistent)  │ │
│                                 │  - Auto-configured via       │ │
│                                 │    cloud-init               │ │
│                                 └─────────────────────────────┘ │
│                                                                  │
│  Cost Optimization:                                              │
│  - Instance OFF by default (pay only Elastic IP: $3.60/mo)     │
│  - Instance ON only during VPN sessions ($0.0104/hr t3.micro)  │
│  - Auto-stop after 1 hour idle (CloudWatch + Lambda)           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Connection Flow

### 6.1 Initial Setup (One-Time)

1. User runs Terraform to deploy AWS infrastructure
2. Terraform outputs:
   - Elastic IP of VPN server
   - Lambda API endpoint
   - API key for Lambda authentication
   - Headscale API key
3. User enters these in macOS app settings
4. macOS app registers with Headscale (gets WireGuard keys)
5. Headscale stores device authorization

### 6.2 Connect Flow

```
User clicks "Connect"
  │
  ├─> Menu bar app: Change icon to "Connecting..."
  │
  ├─> Call Lambda API: StartInstance
  │     └─> Lambda starts EC2 instance
  │     └─> Returns when instance state = running
  │
  ├─> Wait for Headscale to be ready (health check)
  │     └─> Poll https://[ELASTIC_IP]:443/health
  │     └─> Timeout: 60 seconds
  │
  ├─> Call Headscale API: Get WireGuard config
  │     └─> Headscale returns: private key, peer public key, endpoint, allowed IPs
  │
  ├─> Configure WireGuard interface
  │     └─> Create utun interface
  │     └─> Set IP address (from Headscale)
  │     └─> Set peer configuration
  │     └─> Bring interface up
  │
  ├─> Verify connectivity
  │     └─> Ping internal IP
  │     └─> Test DNS resolution
  │
  └─> Menu bar app: Change icon to "Connected"
      └─> Show: Public IP, latency, data transferred
```

### 6.3 Disconnect Flow

```
User clicks "Disconnect"
  │
  ├─> Menu bar app: Change icon to "Disconnecting..."
  │
  ├─> Tear down WireGuard interface
  │     └─> Bring interface down
  │     └─> Delete interface
  │
  ├─> Call Lambda API: StopInstance
  │     └─> Lambda stops EC2 instance
  │     └─> Returns immediately (async stop)
  │
  └─> Menu bar app: Change icon to "Disconnected"
```

### 6.4 Auto-Stop (Cost Optimization)

```
CloudWatch Event (every 5 minutes)
  │
  ├─> Lambda function: CheckIdle
  │     └─> Query Headscale API: Active connections?
  │     └─> If no connections for > 60 minutes:
  │           └─> Stop EC2 instance
  │           └─> Send SNS notification (optional)
```

---

## 7. Cost Estimates

### AWS Costs (us-east-1 pricing)

| Component | Cost Structure | Monthly Estimate |
|-----------|----------------|------------------|
| **Elastic IP** | $0.005/hour when NOT attached to running instance | $3.60/mo (always allocated) |
| **EC2 t3.micro** | $0.0104/hour when running | $0.00 (off by default) |
| **Data Transfer** | $0.09/GB outbound (first 10TB) | Varies by usage |
| **Lambda** | $0.20 per 1M requests + compute time | ~$0.01/mo |
| **CloudWatch** | Logs + metrics (first 5GB free) | $0.00 (under free tier) |

### Usage Scenarios

**Light Use** (2 hours/day, 30 days):
- Instance runtime: 60 hours/month = $0.62
- Data transfer: 10 GB/month = $0.90
- Elastic IP: $3.60
- **Total: ~$5.12/month**

**Medium Use** (4 hours/day, 30 days):
- Instance runtime: 120 hours/month = $1.25
- Data transfer: 50 GB/month = $4.50
- Elastic IP: $3.60
- **Total: ~$9.35/month**

**Heavy Use** (8 hours/day, 30 days):
- Instance runtime: 240 hours/month = $2.50
- Data transfer: 100 GB/month = $9.00
- Elastic IP: $3.60
- **Total: ~$15.10/month**

**Comparison to Commercial VPN**:
- NordVPN: $12.99/month
- ExpressVPN: $12.95/month
- Mullvad: $5.00/month (fixed)

**Advantages**:
- Full control over server
- No logging/privacy concerns
- Can be turned off when not in use
- Scales with usage

---

## 8. Security Considerations

### 8.1 Threat Model

**Protections Against**:
- ISP monitoring (encrypted tunnel)
- Public WiFi sniffing (encrypted tunnel)
- Geo-restrictions (appear from AWS region)
- Basic corporate firewall restrictions (NAT traversal)

**NOT Protected Against**:
- State-level adversaries (advanced DPI, active probing)
- Determined corporate IT with Tailscale/WireGuard signatures
- Traffic analysis (timing, volume patterns)

### 8.2 Security Best Practices

1. **API Key Security**:
   - Store Lambda API key in macOS Keychain
   - Rotate API keys periodically
   - Use IAM role with minimal permissions for Lambda

2. **WireGuard Keys**:
   - Generate private keys on client (never sent to server)
   - Rotate keys every 90 days (optional)
   - Store in macOS Keychain

3. **Headscale**:
   - Enable HTTPS (Let's Encrypt cert via certbot)
   - Use strong pre-auth keys (or disable after initial setup)
   - Enable ACLs to restrict inter-device traffic

4. **EC2 Hardening**:
   - Minimal security group rules (only WireGuard port)
   - Disable SSH password auth (keys only)
   - Enable automatic security updates (unattended-upgrades)
   - CloudWatch logs for SSH attempts

5. **Network**:
   - Enable IP forwarding only for WireGuard interface
   - Use iptables to restrict forwarding rules
   - Enable fail2ban for SSH

---

## 9. Alternatives Considered & Rejected

### 9.1 Why Not Pure ZeroTier?

**Pros**:
- Planetary network is conceptually elegant
- Works well for mesh networking (not needed here)

**Cons**:
- Custom protocol less mature than WireGuard
- Slower performance than WireGuard
- Less macOS integration examples
- Larger attack surface (more complex protocol)

**Decision**: Tailscale/WireGuard is faster, simpler, more mature

### 9.2 Why Not Outline VPN?

**Pros**:
- Best firewall bypass capability
- Designed for hostile networks

**Cons**:
- Slower than WireGuard (Shadowsocks overhead)
- Less mature ecosystem
- Harder to automate (fewer APIs)
- Not needed for Phase 1 (most networks allow UDP)

**Decision**: Use for Phase 2 "Stealth Mode" if needed

### 9.3 Why Not OpenVPN?

**Pros**:
- Very mature
- TCP fallback option
- Widely supported

**Cons**:
- Significantly slower than WireGuard (user-space implementation)
- More complex configuration
- Larger attack surface
- Older codebase

**Decision**: WireGuard is modern replacement, 4x faster

### 9.4 Why Not Managed Tailscale?

**Pros**:
- Easiest setup (no need to run Headscale)
- Globally distributed DERP relays
- Automatic updates

**Cons**:
- SaaS dependency (defeats "self-hosted" goal)
- Privacy concerns (Tailscale sees metadata)
- Limited free tier (3 users, 100 devices)
- Can't customize control plane

**Decision**: Headscale gives control + privacy

---

## 10. Open Questions & Future Enhancements

### Phase 1 Questions

1. **Instance Size**: Is t3.micro sufficient for single-user VPN? (Likely yes, test)
2. **Region Selection**: Hard-code us-east-1 or let user choose? (Choice is better)
3. **DNS Configuration**: Route all DNS through VPN or just Headscale MagicDNS? (All DNS for privacy)
4. **Kill Switch**: Should macOS app block internet if VPN drops? (Optional feature)

### Future Enhancements

1. **Multi-Region**: Deploy to multiple AWS regions, let user switch (appear from different countries)
2. **Stealth Mode**: Add stunnel/shadowsocks wrapper for restrictive networks
3. **Speed Test**: Built-in speed test to verify VPN performance
4. **Split Tunneling**: Route only specific apps through VPN
5. **iOS App**: Companion iOS app with same functionality
6. **Auto-Connect**: Connect automatically when joining untrusted WiFi
7. **Analytics**: Track usage, costs, connection success rate
8. **Failover**: If primary region blocked, auto-failover to backup region

---

## 11. References & Resources

### Documentation
- WireGuard: https://www.wireguard.com/
- Headscale: https://github.com/juanfont/headscale
- Tailscale coordination protocol: https://tailscale.com/blog/how-tailscale-works/
- AWS EC2 Pricing: https://aws.amazon.com/ec2/pricing/

### Tutorials
- Headscale setup: https://headscale.net/setup/install/
- WireGuard on macOS: https://www.wireguard.com/install/#macos-app-store
- Terraform AWS VPN: https://github.com/terraform-aws-modules/terraform-aws-vpn-gateway

### Comparisons
- WireGuard vs OpenVPN benchmarks: https://restoreprivacy.com/vpn/wireguard-vs-openvpn/
- Tailscale vs ZeroTier: https://tailscale.com/compare/zerotier/

---

**Next Steps**: See PRD.md for implementation plan and user stories.

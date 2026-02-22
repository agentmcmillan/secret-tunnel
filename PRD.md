# ZeroTeir - Product Requirements Document

**Version**: 1.0
**Date**: 2026-02-21
**Status**: Planning

---

## 1. Overview

### 1.1 Product Vision

ZeroTeir is an on-demand, self-hosted VPN solution that provides privacy and firewall bypass capabilities while minimizing costs through intelligent instance management. Users can establish a secure VPN connection with a single click from their macOS menu bar, with AWS infrastructure automatically starting when needed and stopping when idle.

### 1.2 Goals

1. **Privacy**: Full control over VPN server, no third-party logging
2. **Cost-Effective**: Infrastructure only runs when actively used ($5-15/month vs $13+ for commercial VPNs)
3. **User Experience**: One-click connect/disconnect from macOS menu bar
4. **Performance**: Modern WireGuard protocol for maximum speed
5. **Reliability**: Automatic NAT traversal, works in most network environments

### 1.3 Non-Goals (Phase 1)

- Mobile apps (iOS/Android)
- Multi-user support
- P2P mesh networking
- Deep packet inspection evasion (reserved for Phase 2)
- Windows/Linux clients

---

## 2. User Stories & Requirements

### Epic 1: AWS Infrastructure Setup

#### US-001: Terraform Infrastructure as Code
**As a** user
**I want to** deploy AWS infrastructure using Terraform
**So that** I can create and manage VPN server resources reliably

**Acceptance Criteria**:
- [ ] Terraform configuration creates EC2 instance (t3.micro, Ubuntu 24.04 LTS)
- [ ] Elastic IP allocated and associated with instance
- [ ] Security groups allow WireGuard (UDP 51820) and Headscale (TCP 443, 8080)
- [ ] SSH access configured (port 22, key-based auth only)
- [ ] CloudWatch logging enabled for system metrics
- [ ] Tags applied for cost tracking

**Story Points**: 5
**Priority**: P0 (Blocker)

**Technical Details**:
- Use `aws_instance` resource with `instance_type = "t3.micro"`
- Use `aws_eip` for Elastic IP
- Use `aws_security_group` with ingress rules for ports
- Output: `elastic_ip`, `instance_id`, `region`

---

#### US-002: EC2 Auto-Configuration (cloud-init)
**As a** user
**I want** the EC2 instance to auto-configure Headscale and WireGuard on first boot
**So that** I don't need to manually SSH and install software

**Acceptance Criteria**:
- [ ] cloud-init script installs Headscale (latest stable version)
- [ ] cloud-init script configures WireGuard kernel module
- [ ] Headscale configured with public Elastic IP as endpoint
- [ ] Headscale systemd service enabled and started
- [ ] Let's Encrypt SSL certificate obtained (certbot) for Headscale HTTPS
- [ ] Health check endpoint available at `https://[ELASTIC_IP]/health`

**Story Points**: 8
**Priority**: P0 (Blocker)

**Technical Details**:
- Use Terraform `user_data` with cloud-init YAML
- Install: `headscale`, `wireguard`, `certbot`
- Configure: `/etc/headscale/config.yaml` with correct `server_url`
- Systemd: `systemctl enable headscale`

---

#### US-003: Lambda Instance Control API
**As a** macOS app
**I want** an API to start and stop the EC2 instance
**So that** I can manage instance lifecycle from the client

**Acceptance Criteria**:
- [ ] API Gateway REST API with three endpoints:
  - `POST /instance/start` - Starts instance, returns when state=running
  - `POST /instance/stop` - Stops instance, returns immediately
  - `GET /instance/status` - Returns instance state (running/stopped/pending)
- [ ] Lambda function implements start/stop logic using AWS SDK
- [ ] API authenticated via API key (passed in `x-api-key` header)
- [ ] IAM role for Lambda with minimal permissions (ec2:StartInstances, ec2:StopInstances, ec2:DescribeInstances)
- [ ] API returns JSON: `{ "status": "running", "publicIp": "...", "uptime": 1234 }`

**Story Points**: 8
**Priority**: P0 (Blocker)

**Technical Details**:
- Lambda runtime: Python 3.12
- Use `boto3` for EC2 operations
- API Gateway: Use usage plan for API key management
- Timeout: 60 seconds (starting instance can take 30-60s)
- Environment variables: `INSTANCE_ID`, `REGION`

---

#### US-004: Auto-Stop Idle Instance
**As a** user
**I want** the EC2 instance to automatically stop after 60 minutes of inactivity
**So that** I minimize AWS costs when I forget to disconnect

**Acceptance Criteria**:
- [ ] CloudWatch Events rule triggers Lambda every 5 minutes
- [ ] Lambda queries Headscale API for active connections
- [ ] If no active connections for > 60 minutes, instance is stopped
- [ ] CloudWatch Logs record auto-stop events
- [ ] (Optional) SNS notification sent when auto-stopped

**Story Points**: 5
**Priority**: P1 (High)

**Technical Details**:
- CloudWatch Events: `rate(5 minutes)`
- Lambda: Query Headscale `/api/v1/machine` endpoint
- Check `lastSeen` timestamp for all machines
- Use `ec2:StopInstances` if all machines idle > 60 min

---

### Epic 2: macOS Menu Bar Application

#### US-005: Menu Bar UI Shell
**As a** user
**I want** a menu bar app with a status icon
**So that** I can quickly access VPN controls

**Acceptance Criteria**:
- [ ] App lives in macOS menu bar (right side, near WiFi/battery)
- [ ] Icon shows VPN status: disconnected (gray), connecting (yellow), connected (green)
- [ ] Clicking icon shows dropdown menu with:
  - Connection status text
  - Connect/Disconnect button
  - Settings option
  - Quit option
- [ ] App launches at login (optional, user configurable)
- [ ] App has proper app icon and bundle ID

**Story Points**: 5
**Priority**: P0 (Blocker)

**Technical Details**:
- SwiftUI for menu bar interface
- Use `NSStatusBar` for menu bar item
- Use `NSMenu` for dropdown
- Assets: 3 SF Symbols or custom icons (gray/yellow/green)

---

#### US-006: Settings UI
**As a** user
**I want** to configure AWS and Headscale credentials in the app
**So that** the app can connect to my infrastructure

**Acceptance Criteria**:
- [ ] Settings window with fields:
  - AWS Region (dropdown: us-east-1, us-west-2, eu-west-1, etc.)
  - Lambda API Endpoint (text input)
  - Lambda API Key (secure text input)
  - Headscale Server URL (text input)
  - Headscale API Key (secure text input)
- [ ] "Test Connection" button validates settings
- [ ] Credentials stored in macOS Keychain (not plain text)
- [ ] Settings window accessible from menu bar dropdown

**Story Points**: 8
**Priority**: P0 (Blocker)

**Technical Details**:
- SwiftUI for settings window
- Use `Security.framework` for Keychain access
- Validation: HTTP request to Lambda API and Headscale health endpoint
- Store non-sensitive config in `UserDefaults`

---

#### US-007: AWS Instance Management
**As a** macOS app
**I want** to start/stop the EC2 instance via Lambda API
**So that** I can bring VPN server online when needed

**Acceptance Criteria**:
- [ ] `InstanceManager` class with methods:
  - `start() async throws -> InstanceInfo`
  - `stop() async throws`
  - `getStatus() async throws -> InstanceStatus`
- [ ] Uses URLSession to call Lambda API endpoints
- [ ] Includes API key in `x-api-key` header
- [ ] Handles errors: network failure, authentication failure, timeout
- [ ] Retry logic for transient failures (3 retries with exponential backoff)
- [ ] Unit tests for InstanceManager

**Story Points**: 8
**Priority**: P0 (Blocker)

**Technical Details**:
- Use Swift `async/await` with `URLSession`
- Model: `InstanceInfo` struct with `publicIp`, `status`, `uptime`
- Error handling: Custom `InstanceError` enum
- Timeout: 60 seconds for start operation

---

#### US-008: Headscale Client Registration
**As a** macOS app
**I want** to register with Headscale on first launch
**So that** I can get WireGuard configuration

**Acceptance Criteria**:
- [ ] On first launch, app checks if registered with Headscale
- [ ] If not registered:
  - Generate WireGuard private key locally
  - Call Headscale API to register machine (POST `/api/v1/machine/register`)
  - Store machine ID and pre-auth key in Keychain
- [ ] If registered:
  - Retrieve existing WireGuard config from Headscale
- [ ] Handle registration errors (invalid API key, network failure)

**Story Points**: 8
**Priority**: P0 (Blocker)

**Technical Details**:
- Use WireGuard key generation library (or shell out to `wg genkey`)
- Headscale API: https://headscale.net/ref/api/
- Store: `machineId`, `privateKey` in Keychain
- Config: `publicKey`, `endpoint`, `allowedIPs`, `dns`

---

#### US-009: WireGuard Tunnel Management
**As a** macOS app
**I want** to create and manage WireGuard tunnel interface
**So that** I can route traffic through the VPN

**Acceptance Criteria**:
- [ ] `TunnelManager` class with methods:
  - `connect(config: WireGuardConfig) async throws`
  - `disconnect() async throws`
  - `getStatus() -> TunnelStatus`
- [ ] Creates `utun` interface using WireGuard macOS library
- [ ] Configures interface with IP, DNS, routes from Headscale config
- [ ] Brings interface up and establishes handshake with server
- [ ] Monitors connection status (connected, disconnected, reconnecting)
- [ ] Handles errors: interface creation failure, handshake timeout

**Story Points**: 13
**Priority**: P0 (Blocker)

**Technical Details**:
- Use WireGuardKit (official WireGuard Swift library)
- Or: Shell out to `wg-quick` with config file
- DNS: Set system DNS to Headscale MagicDNS (100.64.0.1)
- Routes: Set default route to tunnel (0.0.0.0/0)
- Network Extension: May need `NEPacketTunnelProvider` for system integration

---

#### US-010: Full Connect Flow
**As a** user
**I want** to click "Connect" and have VPN automatically established
**So that** I can browse the internet securely with one click

**Acceptance Criteria**:
- [ ] User clicks "Connect" in menu bar dropdown
- [ ] Icon changes to "Connecting..." (yellow)
- [ ] App calls InstanceManager.start() to start EC2 instance
- [ ] Progress indicator shows "Starting instance..." (30-60s)
- [ ] App polls Headscale health endpoint until ready
- [ ] App retrieves WireGuard config from Headscale
- [ ] App calls TunnelManager.connect() to establish tunnel
- [ ] App verifies connectivity (ping internal IP, check public IP)
- [ ] Icon changes to "Connected" (green)
- [ ] Menu shows: "Connected", public IP, latency, uptime
- [ ] If any step fails, show error alert and revert to disconnected state

**Story Points**: 13
**Priority**: P0 (Blocker)

**Technical Details**:
- Implement as async state machine: `disconnected -> starting_instance -> waiting_headscale -> connecting_tunnel -> connected`
- Timeout: 120 seconds total (60s instance start, 30s Headscale ready, 30s tunnel)
- Verification: Use URLSession to check `https://api.ipify.org` for public IP
- Error handling: Rollback state on failure (stop instance if tunnel fails)

---

#### US-011: Full Disconnect Flow
**As a** user
**I want** to click "Disconnect" and have VPN cleanly torn down
**So that** I can return to normal internet and save AWS costs

**Acceptance Criteria**:
- [ ] User clicks "Disconnect" in menu bar dropdown
- [ ] Icon changes to "Disconnecting..." (yellow)
- [ ] App calls TunnelManager.disconnect() to tear down tunnel
- [ ] App calls InstanceManager.stop() to stop EC2 instance
- [ ] Icon changes to "Disconnected" (gray)
- [ ] Menu shows: "Disconnected"
- [ ] If tunnel teardown fails, still attempt to stop instance

**Story Points**: 5
**Priority**: P0 (Blocker)

**Technical Details**:
- Implement as async state machine: `connected -> disconnecting_tunnel -> stopping_instance -> disconnected`
- Don't wait for instance to fully stop (async operation, returns immediately)
- Always tear down tunnel first (even if instance stop fails)

---

#### US-012: Connection Status Monitoring
**As a** user
**I want** to see real-time VPN status and metrics
**So that** I know my VPN is working correctly

**Acceptance Criteria**:
- [ ] When connected, menu shows:
  - Public IP address (from VPN server)
  - Latency (ping time to VPN server)
  - Data transferred (bytes sent/received)
  - Connection uptime (HH:MM:SS)
- [ ] Metrics update every 5 seconds
- [ ] If connection drops, icon changes to yellow (reconnecting) and attempts to reconnect
- [ ] After 3 failed reconnect attempts, changes to red (disconnected) and shows error

**Story Points**: 8
**Priority**: P1 (High)

**Technical Details**:
- Use Timer to poll WireGuard interface stats (`wg show utunX`)
- Parse output for: `transfer`, `latest handshake`
- Latency: ICMP ping to VPN server internal IP (100.64.0.1)
- Reconnect: Attempt to re-establish tunnel without stopping instance

---

### Epic 3: Developer Experience & Deployment

#### US-013: Setup Documentation
**As a** new user
**I want** clear documentation to set up ZeroTeir
**So that** I can deploy it without prior knowledge

**Acceptance Criteria**:
- [ ] README.md with:
  - Project overview
  - Prerequisites (AWS account, Terraform, Xcode)
  - Step-by-step setup instructions
  - Cost estimates
  - Troubleshooting guide
- [ ] Terraform README with required variables and outputs
- [ ] macOS app README with build instructions

**Story Points**: 3
**Priority**: P1 (High)

---

#### US-014: Terraform Output Values
**As a** user
**I want** Terraform to output all values needed for macOS app
**So that** I can easily configure the app after deployment

**Acceptance Criteria**:
- [ ] After `terraform apply`, outputs are displayed:
  - `vpn_server_ip` (Elastic IP)
  - `lambda_api_endpoint` (API Gateway URL)
  - `lambda_api_key` (API key for authentication)
  - `headscale_url` (https://[ELASTIC_IP]:443)
  - `region` (AWS region)
- [ ] Instructions shown: "Copy these values to macOS app Settings"

**Story Points**: 2
**Priority**: P0 (Blocker)

**Technical Details**:
- Use Terraform `output` blocks
- Mark `lambda_api_key` as sensitive
- Provide copy-pasteable format

---

#### US-015: macOS App Code Signing & Distribution
**As a** developer
**I want** the macOS app to be code-signed
**So that** macOS Gatekeeper allows it to run

**Acceptance Criteria**:
- [ ] App is code-signed with Developer ID (for distribution outside App Store)
- [ ] Entitlements include:
  - `com.apple.security.network.client` (network access)
  - `com.apple.security.network.server` (if needed for WireGuard)
  - Keychain access
- [ ] App is notarized by Apple (for macOS 10.15+)
- [ ] DMG installer created for easy installation

**Story Points**: 5
**Priority**: P1 (High)

**Technical Details**:
- Use `codesign` with Developer ID certificate
- Use `xcrun notarytool` for notarization
- Use `create-dmg` tool for DMG creation

---

### Epic 4: Testing & Quality Assurance

#### US-016: Integration Tests
**As a** developer
**I want** automated tests for critical flows
**So that** I can catch regressions

**Acceptance Criteria**:
- [ ] Unit tests for:
  - InstanceManager (mock Lambda API)
  - TunnelManager (mock WireGuard interface)
  - Keychain storage/retrieval
- [ ] Integration tests for:
  - Full connect flow (against real AWS infrastructure)
  - Full disconnect flow
  - Error handling (invalid API key, instance start failure)
- [ ] CI/CD pipeline (GitHub Actions) runs tests on PR

**Story Points**: 13
**Priority**: P2 (Medium)

---

#### US-017: Manual Test Plan
**As a** QA tester
**I want** a manual test plan
**So that** I can verify functionality before release

**Acceptance Criteria**:
- [ ] Test plan document with scenarios:
  - First-time setup (Terraform deploy, app configuration)
  - Connect from home network
  - Connect from restrictive network (coffee shop WiFi)
  - Disconnect and verify instance stops
  - Auto-stop after idle timeout
  - Reconnect after network change (WiFi to Ethernet)
  - Multiple connect/disconnect cycles
  - Invalid credentials handling
- [ ] Each scenario has expected results and pass/fail criteria

**Story Points**: 3
**Priority**: P1 (High)

---

### Epic 5: Observability & Debugging

#### US-018: Application Logging
**As a** developer
**I want** detailed logs from the macOS app
**So that** I can debug connection issues

**Acceptance Criteria**:
- [ ] App uses structured logging (OSLog or similar)
- [ ] Log levels: DEBUG, INFO, WARN, ERROR
- [ ] Logs include:
  - State transitions (connecting, connected, disconnecting)
  - API calls (Lambda, Headscale) with response codes
  - WireGuard interface events
  - Errors with stack traces
- [ ] Logs viewable in Console.app (macOS system logs)
- [ ] (Optional) In-app log viewer in Settings

**Story Points**: 5
**Priority**: P1 (High)

**Technical Details**:
- Use `os.log` for macOS native logging
- Subsystem: `com.zeroteir.vpn`
- Categories: `instance`, `tunnel`, `api`, `ui`

---

#### US-019: CloudWatch Metrics
**As a** user
**I want** AWS CloudWatch metrics for VPN usage
**So that** I can monitor costs and performance

**Acceptance Criteria**:
- [ ] Custom CloudWatch metrics:
  - VPN connection count (gauge)
  - Data transfer (bytes, counter)
  - Instance uptime (seconds, gauge)
  - Connection failures (counter)
- [ ] CloudWatch dashboard with graphs for above metrics
- [ ] (Optional) CloudWatch Alarms for high costs or failures

**Story Points**: 8
**Priority**: P2 (Medium)

**Technical Details**:
- Lambda publishes metrics via `boto3.put_metric_data()`
- Namespace: `ZeroTeir/VPN`
- Dimensions: `InstanceId`, `Region`

---

## 3. Technical Architecture

### 3.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         macOS Menu Bar App                       │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  Presentation Layer (SwiftUI)                                ││
│  │  - MenuBarView: Status icon + dropdown menu                  ││
│  │  - SettingsView: Configuration UI                            ││
│  │  - StatusView: Connection metrics display                    ││
│  └─────────────────┬───────────────────────────────────────────┘│
│                    │                                             │
│  ┌─────────────────▼───────────────────────────────────────────┐│
│  │  Application Layer                                           ││
│  │  - AppState: Central state machine (disconnected/connecting/ ││
│  │    connected/disconnecting)                                  ││
│  │  - ConnectionService: Orchestrates connect/disconnect flows  ││
│  └─────────────────┬───────────────────────────────────────────┘│
│                    │                                             │
│  ┌─────────────────▼───────────────────────────────────────────┐│
│  │  Service Layer                                               ││
│  │  - InstanceManager: AWS instance lifecycle (Lambda API)      ││
│  │  - HeadscaleClient: Machine registration, config retrieval   ││
│  │  - TunnelManager: WireGuard interface management             ││
│  │  - KeychainService: Secure credential storage                ││
│  └─────────────────┬───────────────────────────────────────────┘│
│                    │                                             │
│  ┌─────────────────▼───────────────────────────────────────────┐│
│  │  Network Layer                                               ││
│  │  - WireGuardKit: Tunnel interface (utunX)                    ││
│  │  - URLSession: HTTP client for APIs                          ││
│  └─────────────────┬───────────────────────────────────────────┘│
└────────────────────┼───────────────────────────────────────────┘
                     │
                     │ HTTPS (Lambda API, Headscale API)
                     │ WireGuard UDP 51820
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Infrastructure                       │
│                                                                  │
│  ┌──────────────────────┐      ┌─────────────────────────────┐ │
│  │   API Gateway +       │      │   EC2 Instance (on-demand)  │ │
│  │   Lambda Function     │      │                             │ │
│  │                       │      │  ┌─────────────────────────┐│ │
│  │  Endpoints:           │      │  │  Headscale Server       ││ │
│  │  - POST /start        │◄────►│  │  - Port 443 (HTTPS)     ││ │
│  │  - POST /stop         │      │  │  - Port 8080 (metrics)  ││ │
│  │  - GET /status        │      │  └─────────────────────────┘│ │
│  │                       │      │                             │ │
│  │  Auth: x-api-key      │      │  ┌─────────────────────────┐│ │
│  └──────────────────────┘      │  │  WireGuard Endpoint     ││ │
│                                 │  │  - Port 51820 (UDP)     ││ │
│  ┌──────────────────────┐      │  └─────────────────────────┘│ │
│  │  CloudWatch           │      │                             │ │
│  │  - Logs               │      │  - Ubuntu 24.04 LTS         │ │
│  │  - Metrics            │      │  - t3.micro                 │ │
│  │  - Alarms             │      │  - Elastic IP: X.X.X.X      │ │
│  └──────────────────────┘      └─────────────────────────────┘ │
│                                                                  │
│  ┌──────────────────────┐                                       │
│  │  EventBridge          │                                       │
│  │  - Trigger Lambda     │                                       │
│  │    every 5 min        │                                       │
│  │  - Auto-stop check    │                                       │
│  └──────────────────────┘                                       │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Technology Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **VPN Protocol** | WireGuard | Modern, fast, secure, kernel-level |
| **Control Plane** | Headscale | Self-hosted Tailscale, open-source |
| **Cloud Provider** | AWS | Widely available, cost-effective |
| **Infrastructure** | Terraform | Declarative IaC, version control |
| **Serverless** | Lambda + API Gateway | Pay-per-use, no server management |
| **macOS Client** | Swift + SwiftUI | Native, performant, small footprint |
| **WireGuard Lib** | WireGuardKit | Official Swift library |
| **Logging** | OSLog (macOS), CloudWatch (AWS) | Native, structured, queryable |

### 3.3 Data Models

#### WireGuardConfig
```swift
struct WireGuardConfig {
    let privateKey: String
    let address: String // e.g., "100.64.0.2/32"
    let dns: [String] // e.g., ["100.64.0.1"]
    let peers: [Peer]
}

struct Peer {
    let publicKey: String
    let endpoint: String // e.g., "1.2.3.4:51820"
    let allowedIPs: [String] // e.g., ["0.0.0.0/0"]
    let persistentKeepalive: Int // e.g., 25
}
```

#### InstanceInfo
```swift
struct InstanceInfo {
    let instanceId: String
    let publicIp: String
    let state: InstanceState
    let uptime: TimeInterval
}

enum InstanceState: String {
    case pending
    case running
    case stopping
    case stopped
}
```

#### ConnectionStatus
```swift
struct ConnectionStatus {
    let state: ConnectionState
    let publicIp: String?
    let latency: TimeInterval?
    let bytesReceived: UInt64
    let bytesSent: UInt64
    let connectedAt: Date?
}

enum ConnectionState {
    case disconnected
    case startingInstance
    case waitingForHeadscale
    case connectingTunnel
    case connected
    case reconnecting
    case disconnecting
    case error(Error)
}
```

### 3.4 State Machine

```
┌──────────────┐
│ DISCONNECTED │
└──────┬───────┘
       │ User clicks "Connect"
       ▼
┌──────────────────┐
│ STARTING_INSTANCE│───────┐ Timeout (60s)
└──────┬───────────┘       │ or Error
       │ Instance running  │
       ▼                   │
┌─────────────────────┐    │
│ WAITING_FOR_HEADSCALE│────┤ Timeout (30s)
└──────┬──────────────┘    │ or Error
       │ Health check OK   │
       ▼                   │
┌──────────────────┐        │
│ CONNECTING_TUNNEL│────────┤ Timeout (30s)
└──────┬───────────┘        │ or Error
       │ Tunnel up          │
       ▼                    ▼
┌───────────┐        ┌──────────┐
│ CONNECTED │◄───────│  ERROR   │
└─────┬─────┘        └──────────┘
      │                    │
      │ User clicks        │ User clicks
      │ "Disconnect"       │ "Retry"
      │                    │
      ▼                    │
┌───────────────┐          │
│ DISCONNECTING │──────────┘
└───────┬───────┘
        │ Tunnel down, instance stopping
        ▼
┌──────────────┐
│ DISCONNECTED │
└──────────────┘
```

---

## 4. Development Roadmap

### Phase 1: MVP (4-6 weeks)

**Week 1-2: AWS Infrastructure**
- US-001: Terraform configuration (EC2, networking, security groups)
- US-002: cloud-init auto-configuration (Headscale, WireGuard)
- US-003: Lambda instance control API
- US-014: Terraform outputs

**Week 3-4: macOS App Foundation**
- US-005: Menu bar UI shell
- US-006: Settings UI and Keychain storage
- US-007: InstanceManager (Lambda API client)
- US-008: HeadscaleClient (registration, config)

**Week 5-6: Connection Logic**
- US-009: TunnelManager (WireGuard interface)
- US-010: Full connect flow
- US-011: Full disconnect flow
- US-012: Connection status monitoring

**Deliverable**: Working end-to-end VPN connection

---

### Phase 2: Polish & Reliability (2-3 weeks)

**Week 7: Cost Optimization**
- US-004: Auto-stop idle instance
- US-019: CloudWatch metrics

**Week 8: Developer Experience**
- US-013: Setup documentation
- US-015: Code signing and distribution
- US-018: Application logging

**Week 9: Testing**
- US-016: Integration tests
- US-017: Manual test plan execution

**Deliverable**: Production-ready app with documentation

---

### Phase 3: Enhancements (Future)

**Firewall Resistance** (2 weeks):
- Add stunnel/shadowsocks wrapper for TCP 443 mode
- "Stealth Mode" toggle in UI
- Fallback protocol detection

**Multi-Region Support** (1 week):
- Deploy to multiple AWS regions
- Region selector in UI
- Auto-failover on connection failure

**Advanced Features** (2 weeks):
- Split tunneling (route only specific apps)
- Kill switch (block internet if VPN drops)
- Auto-connect on untrusted WiFi
- iOS companion app

---

## 5. Success Metrics

### 5.1 Technical Metrics

- **Connection Success Rate**: >95% successful connections on first attempt
- **Connection Time**: <60 seconds from "Connect" to tunnel established
- **Performance**: >50 Mbps throughput on 100 Mbps connection (50% efficiency)
- **Latency**: <50ms added latency over direct connection (for same-region server)
- **Reliability**: <1% connection drops per hour
- **Cost**: <$10/month for typical usage (4 hours/day)

### 5.2 User Experience Metrics

- **Setup Time**: <30 minutes from zero to first connection
- **Ease of Use**: Non-technical user can set up without assistance (with docs)
- **Crashes**: <1 crash per 100 hours of usage
- **UI Responsiveness**: <100ms response to user actions

---

## 6. Risks & Mitigations

### 6.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| WireGuard blocked by firewall | Medium | High | Phase 2: Add TCP 443 fallback mode |
| EC2 instance start time too slow | Low | Medium | Use warm instances (keep running for 5 min after disconnect) |
| Headscale registration issues | Medium | High | Comprehensive error handling, retry logic |
| macOS permission prompts confuse users | Medium | Medium | Clear documentation, first-run wizard |
| Lambda cold start delays | Low | Low | Use provisioned concurrency (small cost) |

### 6.2 Cost Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Forgetting to disconnect, instance runs 24/7 | High | High | Auto-stop after 60 min idle (US-004) |
| High data transfer costs | Medium | Medium | CloudWatch alerts for >100 GB/month |
| Multiple users share account, instance always on | Low | High | Document single-user limitation, add usage monitoring |

### 6.3 Security Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| API key leaked in code | Low | Critical | Store in Keychain, never commit to git |
| EC2 instance compromised | Low | High | Minimal security groups, regular updates, fail2ban |
| WireGuard key theft | Low | High | Key rotation every 90 days (optional) |
| Man-in-the-middle on Headscale API | Very Low | Medium | HTTPS with Let's Encrypt certificate |

---

## 7. Dependencies

### 7.1 External Dependencies

- **AWS Account**: User must have AWS account with billing enabled
- **Terraform**: User must install Terraform (>= 1.0)
- **Xcode**: User must have Xcode (>= 15) to build macOS app
- **macOS Version**: Requires macOS 13+ (Ventura or later) for SwiftUI features
- **Internet**: Obviously required for VPN

### 7.2 Library Dependencies

**macOS App**:
- WireGuardKit (Swift package): WireGuard protocol implementation
- (Optional) NetworkExtension.framework: System VPN integration

**Lambda**:
- boto3 (Python): AWS SDK for EC2 operations

**Terraform**:
- AWS provider (>= 5.0)

---

## 8. Open Questions

1. **WireGuard Integration**: Use WireGuardKit or shell out to `wg-quick`?
   - **Recommendation**: Start with `wg-quick` for simplicity, migrate to WireGuardKit if needed

2. **DNS Configuration**: Route all DNS through VPN or only MagicDNS?
   - **Recommendation**: All DNS for privacy (set system DNS to 100.64.0.1)

3. **Instance Warm-Up**: Keep instance running for 5 min after disconnect to avoid cold starts?
   - **Recommendation**: No, stop immediately to minimize costs (cold start acceptable)

4. **Multi-User**: Support multiple devices per user?
   - **Recommendation**: Yes, Headscale supports multiple machines per user (no code changes needed)

5. **Region Selection**: Hard-code region or let user choose?
   - **Recommendation**: Let user choose in Settings (phase 1: single region, phase 2: multi-region)

6. **Update Mechanism**: Auto-update for macOS app?
   - **Recommendation**: Phase 2, use Sparkle framework

---

## 9. Future Roadmap (Post-MVP)

### 9.1 Short Term (3-6 months)

- **iOS App**: Companion app with same functionality
- **Multi-Region**: Deploy to 5+ AWS regions, auto-select closest
- **Stealth Mode**: Add obfuscation for restrictive networks
- **Analytics Dashboard**: Web dashboard showing usage, costs, connection history

### 9.2 Medium Term (6-12 months)

- **Desktop Apps**: Windows and Linux clients
- **Kill Switch**: Network lockdown if VPN drops
- **Split Tunneling**: Per-app routing rules
- **Custom DNS**: User-configurable DNS servers (Pi-hole, etc.)

### 9.3 Long Term (12+ months)

- **P2P Mode**: Direct device-to-device connections (like Tailscale)
- **Cloud Provider Agnostic**: Support GCP, Azure, DigitalOcean
- **Multi-Hop**: Route through multiple servers for extra privacy
- **Tor Integration**: Exit through Tor network

---

## 10. Appendix

### 10.1 Glossary

- **Headscale**: Self-hosted, open-source implementation of Tailscale control server
- **WireGuard**: Modern VPN protocol, fast and secure
- **DERP**: Designated Encrypted Relay for Packets (Tailscale's relay protocol)
- **NAT Traversal**: Techniques to establish direct connections through firewalls
- **utun**: macOS virtual network interface (userspace tunnel)
- **MagicDNS**: Tailscale/Headscale feature for automatic DNS resolution

### 10.2 References

- [WireGuard Protocol](https://www.wireguard.com/)
- [Headscale Documentation](https://headscale.net/)
- [Tailscale Architecture](https://tailscale.com/blog/how-tailscale-works/)
- [AWS Terraform Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [WireGuardKit (Swift)](https://github.com/WireGuard/wireguard-apple)

---

**Document Status**: Ready for Development
**Next Steps**:
1. Review and approve PRD
2. Set up project repository
3. Begin US-001 (Terraform infrastructure)

---

*For detailed research findings, see RESEARCH.md*

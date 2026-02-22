# ZeroTeir Architecture

## Overview

ZeroTeir is a macOS menu bar application that orchestrates on-demand VPN connections through AWS EC2 instances managed via Lambda, coordinated by Headscale, and secured with WireGuard.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     macOS Menu Bar App                       │
│                        (ZeroTeir)                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │   Menu Bar  │  │   Settings   │  │   Onboarding   │   │
│  │   Popover   │  │    Window    │  │     Window      │   │
│  └──────┬──────┘  └──────┬───────┘  └────────┬────────┘   │
│         │                 │                    │             │
│         └─────────────────┴────────────────────┘             │
│                           │                                  │
│                    ┌──────▼──────┐                          │
│                    │   AppState  │                          │
│                    │ (@Observable)│                          │
│                    └──────┬──────┘                          │
│                           │                                  │
│                  ┌────────▼─────────┐                       │
│                  │ ConnectionService │                       │
│                  └────────┬─────────┘                       │
│                           │                                  │
│         ┌─────────────────┼─────────────────┐               │
│         │                 │                 │               │
│  ┌──────▼───────┐ ┌──────▼──────┐ ┌────────▼────────┐     │
│  │   Instance   │ │  Headscale  │ │     Tunnel      │     │
│  │   Manager    │ │   Client    │ │    Manager      │     │
│  └──────┬───────┘ └──────┬──────┘ └────────┬────────┘     │
│         │                 │                 │               │
└─────────┼─────────────────┼─────────────────┼───────────────┘
          │                 │                 │
          │                 │                 │
     ┌────▼────┐       ┌────▼────┐      ┌────▼─────┐
     │ Lambda  │       │Headscale│      │WireGuard │
     │   API   │       │   API   │      │   CLI    │
     └────┬────┘       └────┬────┘      └────┬─────┘
          │                 │                 │
          │                 │                 │
     ┌────▼─────┐      ┌────▼─────┐     ┌────▼─────┐
     │   EC2    │      │Headscale │     │ wg-quick │
     │ Instance │◄─────┤  Server  │     │   (OS)   │
     └──────────┘      └──────────┘     └──────────┘
```

## Component Architecture

### Application Layer

#### ZeroTeirApp
- Entry point (`@main`)
- Uses `NSApplicationDelegateAdaptor` for AppDelegate
- Sets activation policy to `.accessory` (no dock icon)
- Implements MenuBarExtra (minimal, actual menu managed by AppDelegate)

#### AppDelegate
- Manages NSStatusItem (menu bar icon)
- Creates and manages NSPopover for menu content
- Observes state changes and updates icon accordingly
- Handles onboarding window presentation
- Icon states based on ConnectionState

### View Layer (SwiftUI)

#### MenuBarView
- Main popover content
- Shows current connection state
- Connect/Disconnect button
- Connection statistics when connected
- Settings and Quit buttons

#### SettingsView
- TabView with Connection and General tabs
- Connection: API endpoints and keys
- General: Launch at login, region, timeout
- Test Connection functionality
- Saves to Keychain and AppSettings

#### OnboardingView
- First-run wizard
- Multi-step setup flow
- Validates and saves configuration

#### StatusView
- Detailed connection statistics
- Grid layout for metrics
- Used in monitoring context

### State Layer

#### AppState (@Observable)
- Central observable state object
- Properties:
  - `connectionState: ConnectionState`
  - `connectionStatus: ConnectionStatus?`
  - `error: AppError?`
  - `settings: AppSettings`
- Thread-safe updates via @MainActor

#### AppSettings (@Observable)
- User configuration
- Properties stored in Keychain (API keys) or UserDefaults (preferences)
- Validation logic for required fields

#### ConnectionState (Enum)
- State machine for connection lifecycle:
  - `.disconnected`
  - `.startingInstance`
  - `.waitingForHeadscale`
  - `.connectingTunnel`
  - `.connected`
  - `.disconnecting`
  - `.error(AppError)`

### Service Layer

#### ConnectionService
- Orchestrates full connection flow
- Owns lifecycle of connection
- Methods:
  - `connect()`: Full connection sequence
  - `disconnect()`: Clean teardown
- Implements retry and rollback logic
- Monitors connection health

#### InstanceManager
- Lambda API client for EC2 instance control
- Methods:
  - `start()`: Start EC2 instance, returns InstanceInfo
  - `stop()`: Stop EC2 instance
  - `getStatus()`: Query current status
- Implements retry with exponential backoff
- Timeout handling

#### HeadscaleClient
- Headscale API client
- Methods:
  - `checkHealth()`: Health endpoint polling
  - `listMachines()`: Get registered machines
  - `getRoutes()`: Get configured routes
  - `createPreAuthKey()`: Generate pre-auth token
- Bearer token authentication

#### TunnelManager
- WireGuard tunnel management via CLI
- Methods:
  - `connect(config)`: Write config, execute wg-quick up
  - `disconnect()`: Execute wg-quick down
  - `getStats()`: Parse `wg show` output
- Uses AppleScript for privilege escalation
- Config stored at `~/.zeroteir/wg0.conf`

#### NetworkMonitor
- NWPathMonitor wrapper
- Tracks network availability
- Measures latency to VPN endpoint
- Observable properties for UI binding

#### KeychainService
- Secure credential storage
- Singleton pattern
- Methods:
  - `save(key, value)`
  - `load(key)`
  - `delete(key)`
- Uses Security framework (SecItem APIs)

### Model Layer

#### InstanceInfo
- EC2 instance data
- Properties: instanceId, status, publicIp, privateIp
- Codable for API serialization

#### WireGuardConfig
- WireGuard configuration model
- Generates INI-format config file
- Properties: keys, addresses, endpoints, DNS

#### ConnectionStatus
- Live connection metrics
- Properties: IP, latency, bytes sent/received, uptime
- Computed formatting properties
- Stale handshake detection

## Data Flow

### Connect Flow

```
User clicks Connect
        ↓
MenuBarView action → ConnectionService.connect()
        ↓
AppState.updateState(.startingInstance)
        ↓
InstanceManager.start() → Lambda API
        ↓
AppState.updateState(.waitingForHeadscale)
        ↓
HeadscaleClient.checkHealth() (polling)
        ↓
AppState.updateState(.connectingTunnel)
        ↓
TunnelManager.connect(config) → wg-quick
        ↓
Verify connection via ipify
        ↓
AppState.updateState(.connected)
        ↓
Start monitoring timer
```

### Monitoring Loop

```
Timer fires every 5s
        ↓
TunnelManager.getStats() → wg show
        ↓
NetworkMonitor.measureLatency()
        ↓
Build ConnectionStatus
        ↓
AppState.updateStatus(status)
        ↓
Check handshake staleness
        ↓
If stale → attempt reconnect
        ↓
If max retries → disconnect with error
```

### Disconnect Flow

```
User clicks Disconnect
        ↓
MenuBarView action → ConnectionService.disconnect()
        ↓
Stop monitoring timer
        ↓
AppState.updateState(.disconnecting)
        ↓
TunnelManager.disconnect() → wg-quick down
        ↓
InstanceManager.stop() (fire-and-forget Task)
        ↓
AppState.updateState(.disconnected)
        ↓
AppState.updateStatus(nil)
```

## Security Architecture

### Credential Storage
- All secrets in macOS Keychain
- Service identifier: `com.zeroteir.vpn`
- Accounts:
  - `lambdaApiKey`
  - `headscaleApiKey`
  - `wireguardPrivateKey`

### Network Security
- HTTPS for all API calls
- WireGuard encryption for VPN tunnel
- Bearer token auth for Headscale
- API key auth for Lambda

### Privilege Escalation
- AppleScript with "administrator privileges"
- User prompted for password on first connection
- Required for `wg-quick` network configuration

### App Sandbox
- Disabled (`LSUIElement = true`)
- Required for:
  - Shell command execution
  - Network configuration
  - Direct file system access

## Error Handling

### Error Types

1. **AppError**: High-level application errors
2. **InstanceError**: EC2/Lambda errors
3. **HeadscaleError**: Headscale API errors
4. **TunnelError**: WireGuard errors
5. **KeychainError**: Keychain access errors

### Error Propagation

```
Service throws Error
        ↓
ConnectionService catches
        ↓
Maps to AppError
        ↓
AppState.updateState(.error(appError))
        ↓
MenuBarView displays error state
```

### Rollback Strategy

On connection failure:
1. Log error
2. Disconnect tunnel (if connected)
3. Stop instance (async, best-effort)
4. Update state to `.error`
5. Clear connection status

## Threading Model

### Main Actor
- All UI updates
- AppState mutations
- ConnectionService (marked @MainActor)

### Background
- Network requests (URLSession)
- WireGuard commands (Process)
- Monitoring timer tasks

### Synchronization
- @Observable for state propagation
- async/await for sequential operations
- Task groups for parallel work

## Performance Considerations

### Connection Time
- Instance start: ~30-60s (AWS EC2)
- Headscale health: ~5-30s (polling)
- Tunnel setup: ~1-2s
- **Total: ~40-90s**

### Monitoring Overhead
- Stats query: ~100ms (wg show)
- Latency ping: ~50-200ms
- Frequency: 5s interval
- **Minimal impact**

### Memory Footprint
- SwiftUI views: ~5MB
- Service objects: ~1MB
- Network buffers: ~2MB
- **Total: ~10-15MB**

## Dependencies

### System Frameworks
- SwiftUI: UI layer
- AppKit: Menu bar, windows
- Foundation: Networking, data structures
- OSLog: Structured logging
- Security: Keychain access
- Network: NWPathMonitor

### External Tools
- WireGuard CLI: `wg`, `wg-quick`
- Location: `/usr/local/bin` or `/opt/homebrew/bin`

### Runtime Services
- Lambda API: Custom endpoint
- Headscale: Self-hosted or managed
- EC2: AWS infrastructure

## Extensibility Points

### Custom Authentication
- Implement custom API client conforming to protocol
- Swap InstanceManager/HeadscaleClient

### Tunnel Backend
- Replace TunnelManager with WireGuardKit
- Use NetworkExtension framework
- Requires VPN entitlement

### Multi-Profile
- Add ProfileManager service
- Store multiple AppSettings
- Switch between profiles in UI

### Metrics/Analytics
- Add MetricsService
- Aggregate connection events
- Export to analytics platform

## Testing Strategy

### Unit Tests
- Model encoding/decoding
- State machine transitions
- Utility functions

### Integration Tests
- InstanceManager with mock Lambda
- HeadscaleClient with test server
- TunnelManager with dummy configs

### UI Tests
- Menu bar interaction
- Settings validation
- Onboarding flow

### Manual Tests
- Full connection cycle
- Network change scenarios
- Error recovery
- Admin privilege prompt

## Build & Distribution

### Local Build
- Swift Package Manager
- No external dependencies
- Makefile for convenience

### App Bundle
- Script to create `.app` structure
- Info.plist configuration
- Entitlements file

### Code Signing
- Developer ID certificate required
- Entitlements for network, keychain
- Notarization for Gatekeeper

### Distribution
- Direct download (DMG)
- GitHub releases
- Homebrew cask (future)
- Mac App Store (requires NetworkExtension rewrite)

## Known Limitations

1. **WireGuard Config**: Placeholder values for server key, client IP
2. **Headscale Integration**: Pre-auth key not used in flow
3. **Launch at Login**: UI toggle not functional
4. **Network Changes**: No auto-reconnect on network switch
5. **CLI Dependency**: Requires WireGuard tools installed

## Future Architecture Changes

### Phase 2: NetworkExtension
- Replace CLI with WireGuardKit
- Use NEPacketTunnelProvider
- Remove admin privilege requirement
- Enable App Sandbox
- App Store compatible

### Phase 3: Multi-Tenancy
- Profile manager
- Per-profile settings
- Quick profile switching
- Import/export configs

### Phase 4: Advanced Features
- Split tunneling
- Custom DNS
- Kill switch
- Traffic statistics
- Connection history
- Notification Center alerts

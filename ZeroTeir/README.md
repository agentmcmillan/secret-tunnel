# ZeroTeir - macOS VPN Menu Bar Application

ZeroTeir is a macOS menu bar application that provides on-demand VPN access through AWS EC2 instances and Headscale (WireGuard coordination server).

## Features

- Menu bar-only application (no dock icon)
- On-demand EC2 instance management via Lambda API
- WireGuard VPN tunnel through Headscale
- Real-time connection monitoring and statistics
- Secure credential storage in macOS Keychain
- Automatic reconnection on connection loss
- Clean disconnect flow with instance cleanup

## Architecture

### Components

- **App**: Entry point and menu bar setup
- **Views**: SwiftUI views for menu bar, settings, and onboarding
- **Models**: Data structures for connection state, instances, and configurations
- **Services**: Business logic for instance management, Headscale, tunnels, and monitoring
- **State**: Observable app state with @Observable macro
- **Utilities**: Logging and constants

### State Machine

```
disconnected → startingInstance → waitingForHeadscale → connectingTunnel → connected
                                                                              ↓
                                                                         disconnecting → disconnected
                                                                              ↓
                                                                            error
```

## Prerequisites

### System Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building)
- Swift 5.9 or later

### Runtime Dependencies

- **WireGuard Tools**: Required for VPN functionality
  ```bash
  brew install wireguard-tools
  ```

### Service Requirements

- Lambda API endpoint with the following endpoints:
  - `POST /instance/start` - Start EC2 instance
  - `POST /instance/stop` - Stop EC2 instance
  - `GET /instance/status` - Get instance status

- Headscale server with API access:
  - `/health` - Health check endpoint
  - `/api/v1/machine` - Machine management
  - `/api/v1/routes` - Route management
  - `/api/v1/preauthkey` - Pre-authentication key creation

## Building

### Using Swift Package Manager (Recommended)

```bash
cd ZeroTeir
swift build -c release
```

The built binary will be at `.build/release/ZeroTeir`.

### Creating an App Bundle

To create a proper macOS application bundle:

```bash
# Build the executable
swift build -c release

# Create app bundle structure
mkdir -p ZeroTeir.app/Contents/MacOS
mkdir -p ZeroTeir.app/Contents/Resources

# Copy executable
cp .build/release/ZeroTeir ZeroTeir.app/Contents/MacOS/

# Copy Info.plist
cp Resources/Info.plist ZeroTeir.app/Contents/

# Copy entitlements (for code signing)
cp Resources/ZeroTeir.entitlements ZeroTeir.app/Contents/

# Make executable
chmod +x ZeroTeir.app/Contents/MacOS/ZeroTeir
```

### Using Xcode (Alternative)

While this project uses Swift Package Manager, you can generate an Xcode project:

```bash
swift package generate-xcodeproj
```

Then open `ZeroTeir.xcodeproj` in Xcode and build normally (⌘B).

## Running

### From Command Line

```bash
./.build/release/ZeroTeir
```

### From App Bundle

```bash
open ZeroTeir.app
```

Or double-click the app in Finder.

## Configuration

On first launch, the onboarding wizard will guide you through:

1. Lambda API configuration
   - API Endpoint URL
   - API Key (stored in Keychain)

2. Headscale configuration
   - Headscale Server URL
   - Headscale API Key (stored in Keychain)

### Manual Configuration

Settings can be accessed from the menu bar dropdown → Settings.

#### Connection Tab
- Lambda API Endpoint
- Lambda API Key
- Headscale URL
- Headscale API Key
- Test Connection button

#### General Tab
- Launch at Login
- AWS Region
- Auto-disconnect timeout (future)

## Usage

### Connecting

1. Click the ZeroTeir icon in the menu bar
2. Click "Connect"
3. The app will:
   - Start the EC2 instance
   - Wait for Headscale to be healthy
   - Configure and connect the WireGuard tunnel
   - Verify the connection

### Disconnecting

1. Click the ZeroTeir icon in the menu bar
2. Click "Disconnect"
3. The app will:
   - Tear down the WireGuard tunnel
   - Stop the EC2 instance (asynchronously)

### Menu Bar Icon States

- **Gray shield with slash**: Disconnected
- **Orange half shield**: Connecting/Disconnecting
- **Green checkered shield**: Connected
- **Red triangle**: Error

### Connection Monitoring

When connected, the menu shows:
- Connected IP address
- Latency (ping time)
- Data sent/received
- Connection uptime
- Last WireGuard handshake

The app monitors the connection every 5 seconds and will attempt to reconnect if the handshake becomes stale (>3 minutes).

## Security

### Keychain Storage

All sensitive credentials are stored in macOS Keychain:
- Lambda API Key
- Headscale API Key
- WireGuard Private Key

### Permissions

The app requires:
- Network access (client and server)
- Administrator privileges (for WireGuard tunnel setup via `wg-quick`)
- Keychain access

### App Sandbox

The app runs **outside** the App Sandbox (`com.apple.security.app-sandbox = false`) because:
- WireGuard tunnel setup requires root privileges
- Direct network configuration is needed

## WireGuard Configuration

### Configuration File

WireGuard configs are stored at: `~/.zeroteir/wg0.conf`

Example:
```ini
[Interface]
PrivateKey = <generated-or-stored-key>
Address = 100.64.0.1/32
DNS = 1.1.1.1

[Peer]
PublicKey = <server-public-key>
Endpoint = <ec2-public-ip>:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

### Privilege Escalation

The app uses AppleScript to prompt for administrator privileges when running `wg-quick`:
```applescript
do shell script "wg-quick up <config>" with administrator privileges
```

## Development

### Project Structure

```
ZeroTeir/
├── Package.swift                  # SPM manifest
├── Sources/ZeroTeir/
│   ├── App/                       # App entry point and delegate
│   ├── Views/                     # SwiftUI views
│   ├── Models/                    # Data models
│   ├── Services/                  # Business logic
│   ├── State/                     # App state management
│   └── Utilities/                 # Helpers
├── Resources/                     # Assets and configuration
└── README.md
```

### Logging

The app uses OSLog for structured logging:
- `Log.instance` - EC2 instance operations
- `Log.tunnel` - WireGuard tunnel operations
- `Log.api` - API calls (Lambda, Headscale)
- `Log.ui` - UI events
- `Log.keychain` - Keychain operations
- `Log.connection` - Connection flow

View logs in Console.app:
```
Subsystem: com.zeroteir.vpn
```

### Error Handling

Custom error types:
- `AppError` - Application-level errors
- `InstanceManager.InstanceError` - Instance management errors
- `HeadscaleClient.HeadscaleError` - Headscale API errors
- `TunnelManager.TunnelError` - WireGuard tunnel errors
- `KeychainService.KeychainError` - Keychain access errors

### Retry Logic

Network requests automatically retry up to 3 times with exponential backoff:
- Attempt 1: Immediate
- Attempt 2: 1 second delay
- Attempt 3: 2 seconds delay
- Attempt 4: 4 seconds delay

## Known Limitations

### Phase 1 (Current Implementation)

1. **WireGuard Configuration**: Currently uses placeholder values for server public key and client IP address. These need to be obtained from Headscale in a production implementation.

2. **Pre-Auth Keys**: The Headscale pre-auth key creation is implemented but not integrated into the connection flow. Full Headscale registration needs to be implemented.

3. **Launch at Login**: Toggle is present in UI but SMAppService integration is not yet implemented.

4. **Network Change Handling**: NetworkMonitor is implemented but doesn't automatically reconnect on network changes.

5. **WireGuard Tools Path**: Assumes WireGuard tools are in `/usr/local/bin` or `/opt/homebrew/bin`. May need adjustment for other installations.

## Troubleshooting

### "WireGuard tools not found"

Install WireGuard tools:
```bash
brew install wireguard-tools
```

### "Permission denied" when connecting

The app needs administrator privileges to configure the WireGuard tunnel. Click "Allow" when prompted.

### Connection fails at "Waiting for Headscale"

1. Check Headscale server is running
2. Verify Headscale URL in settings
3. Check network connectivity to Headscale server
4. Verify Headscale API key is correct

### Connection succeeds but no internet

1. Check WireGuard tunnel is up: `wg show`
2. Verify routing: `netstat -rn`
3. Check EC2 instance security groups
4. Verify Headscale routes are configured

## Future Enhancements

- [ ] Full Headscale machine registration flow
- [ ] Launch at login with SMAppService
- [ ] Auto-reconnect on network changes
- [ ] Multiple VPN profiles
- [ ] Connection history and statistics
- [ ] Notification Center integration
- [ ] Advanced routing options
- [ ] WireGuardKit/NetworkExtension integration (avoid CLI tools)
- [ ] App Store distribution

## License

Copyright © 2026. All rights reserved.

## Support

For issues and questions, please open an issue on the GitHub repository.

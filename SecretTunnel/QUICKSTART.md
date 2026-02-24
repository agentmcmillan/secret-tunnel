# ZeroTeir Quick Start Guide

## Installation

### 1. Install WireGuard Tools

```bash
brew install wireguard-tools
```

### 2. Build ZeroTeir

```bash
cd ZeroTeir
./build.sh
```

Or use Make:
```bash
make build
```

## First Run

### 1. Launch the App

```bash
./.build/release/ZeroTeir
```

Or create and launch the app bundle:
```bash
make bundle
open ZeroTeir.app
```

### 2. Complete Setup Wizard

On first launch, you'll see the onboarding wizard:

**Step 1: Welcome**
- Introduction to ZeroTeir

**Step 2: Lambda API Configuration**
- Lambda API Endpoint: `https://your-api-gateway.execute-api.region.amazonaws.com/prod`
- Lambda API Key: Your API Gateway key

**Step 3: Headscale Configuration**
- Headscale URL: `https://your-headscale-server.com`
- Headscale API Key: Your Headscale API token

**Step 4: Complete**
- Click "Get Started"

## Using ZeroTeir

### Connecting to VPN

1. Click the ZeroTeir icon in the menu bar (shield icon)
2. Click "Connect" button
3. Wait for connection (may take 30-60 seconds)
4. Icon turns green when connected

### Viewing Connection Stats

When connected, the menu shows:
- Connected IP address
- Latency
- Data transferred
- Uptime

### Disconnecting

1. Click the ZeroTeir icon
2. Click "Disconnect" button

### Accessing Settings

1. Click the ZeroTeir icon
2. Click "Settings..."
3. Modify configuration as needed
4. Click "Test Connection" to verify
5. Click "Save"

## Troubleshooting

### Connection Fails

**Check WireGuard tools:**
```bash
which wg
which wg-quick
```

**Check Headscale connectivity:**
```bash
curl -I https://your-headscale-server.com/health
```

**Check Lambda API:**
```bash
curl -H "x-api-key: YOUR_KEY" https://your-api-gateway.com/instance/status
```

### Permission Issues

When connecting, you'll be prompted for administrator password. This is required to configure the WireGuard tunnel.

### View Logs

Open Console.app and filter by subsystem: `com.zeroteir.vpn`

## Testing

### Test Lambda API

In Settings → Connection tab, click "Test Connection" to verify:
- Lambda API is reachable
- API key is valid
- Headscale is healthy

### Manual WireGuard Test

Check if WireGuard is running:
```bash
sudo wg show
```

Check tunnel status:
```bash
ifconfig wg0
```

### Check Routes

```bash
netstat -rn | grep wg0
```

## Uninstallation

### 1. Quit ZeroTeir

Click menu bar icon → "Quit ZeroTeir"

### 2. Remove Application

```bash
rm -rf ZeroTeir.app
rm -rf .build
```

### 3. Remove Configuration

```bash
rm -rf ~/.zeroteir
```

### 4. Remove Keychain Entries

Open Keychain Access.app and search for "zeroteir", delete entries.

## Next Steps

- Configure Launch at Login in Settings → General
- Review connection logs in Console.app
- Set up additional VPN profiles (future feature)

## Support

For issues, check:
1. Console.app logs (subsystem: com.zeroteir.vpn)
2. WireGuard status: `sudo wg show`
3. Network connectivity
4. AWS/Headscale server status

Report bugs on GitHub: [your-repo-url]

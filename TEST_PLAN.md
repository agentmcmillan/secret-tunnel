# Secret Tunnel - Manual Test Plan

## Prerequisites
- Secret Tunnel app installed
- AWS infrastructure deployed (`terraform apply`)
- App configured with API endpoint, API key, Headscale URL

---

## Test Scenarios

### 1. First-Time Setup
| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 1.1 | Deploy terraform | 37 resources created, outputs shown | |
| 1.2 | Run `setup.sh` | Interactive setup completes, outputs API endpoint + key | |
| 1.3 | Install DMG | App appears in /Applications, opens from menu bar | |
| 1.4 | Open app first time | Onboarding screen shown | |
| 1.5 | Enter credentials | Settings saved, "Test Connection" passes | |

### 2. Connect from Home Network
| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 2.1 | Click Connect | Icon changes to connecting (yellow) | |
| 2.2 | Wait for instance start | Status shows "Starting instance..." (30-60s) | |
| 2.3 | Wait for Headscale | Status shows "Waiting for Headscale..." | |
| 2.4 | Wait for tunnel | Status shows "Connecting tunnel..." | |
| 2.5 | Connected | Icon green, public IP shown, latency displayed | |
| 2.6 | Check ipify.org | Public IP matches AWS Elastic IP | |
| 2.7 | Browse internet | Web pages load normally | |

### 3. Connect from Restrictive Network (Coffee Shop WiFi)
| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 3.1 | Join coffee shop WiFi | WiFi connected | |
| 3.2 | Click Connect | Connection flow starts | |
| 3.3 | Wait for completion | VPN established, green icon | |
| 3.4 | Browse internet | Pages load through VPN | |

### 4. Disconnect and Verify Instance Stops
| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 4.1 | Click Disconnect | Icon changes to disconnecting | |
| 4.2 | Wait for completion | Icon gray, "Disconnected" shown | |
| 4.3 | Check AWS console | Instance state = stopping/stopped | |
| 4.4 | Check public IP | Public IP is local ISP, not AWS | |

### 5. Auto-Stop After Idle Timeout
| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 5.1 | Connect VPN | Connected successfully | |
| 5.2 | Disconnect VPN (keep instance) | Tunnel down, instance still running | |
| 5.3 | Wait 65 minutes | CloudWatch idle monitor triggers | |
| 5.4 | Check AWS console | Instance auto-stopped | |

### 6. Reconnect After Network Change
| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 6.1 | Connect VPN on WiFi | Connected successfully | |
| 6.2 | Switch to Ethernet | Network change detected | |
| 6.3 | Check connection | Tunnel health checked, reconnect if stale | |
| 6.4 | Switch back to WiFi | Connection maintained or auto-reconnected | |

### 7. Multiple Connect/Disconnect Cycles
| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 7.1 | Connect | Connected | |
| 7.2 | Disconnect | Disconnected | |
| 7.3 | Connect again | Connected (faster, instance may still be running) | |
| 7.4 | Disconnect again | Disconnected cleanly | |
| 7.5 | Repeat 3 more times | No errors, no resource leaks | |

### 8. Invalid Credentials Handling
| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 8.1 | Enter wrong API key | "Test Connection" fails with auth error | |
| 8.2 | Enter wrong API endpoint | Connection fails with network error | |
| 8.3 | Enter wrong Headscale URL | Connection fails at Headscale health step | |
| 8.4 | Fix credentials | Connection succeeds | |

### 9. Kill Switch
| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 9.1 | Enable kill switch in Settings | Setting saved | |
| 9.2 | Connect VPN | Connected with kill switch active | |
| 9.3 | Verify internet works | Pages load through VPN | |
| 9.4 | Disconnect VPN | Internet blocked (no non-VPN traffic) | |
| 9.5 | Disable kill switch | Normal internet restored | |

### 10. Auto-Connect on Untrusted WiFi
| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 10.1 | Enable auto-connect in Settings | Setting saved | |
| 10.2 | Add home WiFi to trusted list | Setting saved | |
| 10.3 | Join untrusted WiFi | VPN auto-connects | |
| 10.4 | Join trusted WiFi | VPN does NOT auto-connect | |

### 11. Split Tunnel (Home LAN)
| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 11.1 | Enable Home LAN in Settings | Setting saved | |
| 11.2 | Enter NAS public key and subnet | Setting saved | |
| 11.3 | Connect VPN | Connected with split tunnel | |
| 11.4 | Access home NAS (192.168.x.x) | Routed via NAS peer | |
| 11.5 | Access internet | Routed via AWS peer | |

### 12. Launch at Login
| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 12.1 | Enable Launch at Login | Setting saved | |
| 12.2 | Log out and log back in | App appears in menu bar | |
| 12.3 | Disable Launch at Login | Setting saved | |
| 12.4 | Log out and log back in | App does NOT appear | |

### 13. Connection Status Display
| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 13.1 | Connect VPN | Status shown in menu | |
| 13.2 | Check public IP | IP address displayed | |
| 13.3 | Check latency | Latency in ms displayed | |
| 13.4 | Check data transferred | Bytes sent/received updating | |
| 13.5 | Check uptime | Timer incrementing | |

---

## Error Recovery Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| Network drops during connect | Error shown, instance rolled back |
| Instance fails to start | Error shown, clean state |
| Headscale health check timeout | Error shown after 30s |
| Tunnel handshake fails | Error shown, rollback to disconnected |
| 3 consecutive stale handshakes | Auto-disconnect with error message |

---

## CloudWatch Verification

| Check | Expected |
|-------|----------|
| Dashboard exists | SecretTunnel dashboard in CloudWatch |
| Instance state metric | Shows 1 when running, 0 when stopped |
| Active connections metric | Shows count of connected nodes |
| CPU utilization graph | Shows EC2 CPU usage |
| Network traffic graph | Shows in/out bytes |
| Lambda logs | Instance control and idle monitor logs visible |

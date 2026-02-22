# VPN Solution Comparison Table

Quick reference for comparing VPN solutions evaluated for ZeroTeir.

---

## Executive Summary

**Recommendation**: WireGuard + Headscale for Phase 1

**Why**: Best balance of performance, ease of use, cost, and self-hosting capability. Add obfuscation in Phase 2 if needed for restrictive networks.

---

## Feature Comparison Matrix

| Feature | WireGuard + Headscale | ZeroTier | Tailscale (SaaS) | OpenVPN | Outline VPN | Nebula |
|---------|----------------------|----------|------------------|---------|-------------|--------|
| **Protocol** | WireGuard | Custom | WireGuard | OpenVPN | Shadowsocks | Custom |
| **Performance** | 1000+ Mbps | ~500 Mbps | 1000+ Mbps | ~250 Mbps | ~400 Mbps | ~800 Mbps |
| **NAT Traversal** | Excellent (DERP) | Excellent | Excellent | Poor | Moderate | Poor |
| **Firewall Bypass** | Moderate (UDP) | Moderate (UDP) | Moderate (UDP) | Good (TCP 443) | Excellent | Poor (UDP only) |
| **Self-Hosting** | Yes (Headscale) | Yes | No (SaaS) | Yes | Yes | Yes |
| **macOS Support** | Excellent | Good | Excellent | Good (Tunnelblick) | Good | Moderate (CLI) |
| **Setup Complexity** | Low | Moderate | Very Low | High | Low | Moderate |
| **Maturity** | High (kernel) | High | High | Very High | Moderate | Moderate |
| **License** | Open Source | BSL 1.1 | Proprietary | GPLv2 | Apache 2.0 | MIT |
| **Cost (Self-Hosted)** | Free | Free | N/A | Free | Free | Free |
| **Cost (SaaS)** | N/A | Free tier | Free tier | N/A | N/A | N/A |
| **API Quality** | Excellent | Good | Excellent | Moderate | Moderate | Moderate |
| **CLI Automation** | Excellent | Good | Excellent | Good | Moderate | Moderate |
| **Documentation** | Excellent | Good | Excellent | Excellent | Good | Good |
| **Community Size** | Very Large | Large | Very Large | Very Large | Moderate | Moderate |
| **Attack Surface** | Minimal | Moderate | Minimal | Large | Small | Moderate |
| **Encryption** | ChaCha20 | Salsa20 | ChaCha20 | AES-256 | AES-256 | AES-256 |
| **Key Exchange** | Curve25519 | Curve25519 | Curve25519 | RSA/DH | N/A (PSK) | ECDH |
| **Mobile Support** | iOS/Android | iOS/Android | iOS/Android | iOS/Android | iOS/Android | iOS/Android |

---

## Detailed Ratings (1-10 scale)

| Criteria | WireGuard + Headscale | ZeroTier | Tailscale (SaaS) | OpenVPN | Outline VPN | Nebula |
|----------|----------------------|----------|------------------|---------|-------------|--------|
| **Speed** | 10 | 7 | 10 | 5 | 6 | 9 |
| **Security** | 10 | 8 | 10 | 8 | 7 | 9 |
| **Ease of Setup** | 8 | 6 | 10 | 4 | 7 | 5 |
| **NAT Traversal** | 9 | 9 | 10 | 3 | 6 | 4 |
| **Firewall Bypass** | 6 | 6 | 6 | 8 | 10 | 4 |
| **Self-Hosting** | 10 | 10 | 0 | 10 | 10 | 10 |
| **macOS Integration** | 9 | 7 | 10 | 7 | 7 | 6 |
| **API/Automation** | 9 | 7 | 10 | 6 | 6 | 6 |
| **Documentation** | 9 | 7 | 10 | 9 | 7 | 7 |
| **Community Support** | 10 | 8 | 10 | 10 | 6 | 6 |
| **Cost (Self-Host)** | 10 | 10 | N/A | 10 | 10 | 10 |
| **Total Score** | 100/110 | 85/110 | 86/100 | 80/110 | 82/110 | 76/110 |

---

## Use Case Suitability

### ZeroTeir Requirements

| Requirement | WireGuard + Headscale | ZeroTier | Tailscale (SaaS) | OpenVPN | Outline VPN | Nebula |
|-------------|----------------------|----------|------------------|---------|-------------|--------|
| On-demand AWS instance | ✅ Perfect | ✅ Good | ❌ SaaS | ✅ Good | ✅ Good | ✅ Good |
| macOS menu bar app | ✅ Excellent | ✅ Good | ✅ Excellent | ✅ Good | ✅ Good | ⚠️ CLI only |
| Self-hosted (privacy) | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| Cost optimization | ✅ Perfect | ✅ Good | ⚠️ SaaS fees | ✅ Good | ✅ Good | ✅ Good |
| NAT traversal (coffee shops) | ✅ Excellent | ✅ Excellent | ✅ Excellent | ❌ Poor | ⚠️ Moderate | ❌ Poor |
| High performance | ✅ 1+ Gbps | ⚠️ 500 Mbps | ✅ 1+ Gbps | ❌ 250 Mbps | ⚠️ 400 Mbps | ✅ 800 Mbps |
| Easy automation | ✅ Clean API | ✅ Good API | ✅ Clean API | ⚠️ Moderate | ⚠️ Moderate | ⚠️ Moderate |
| Future: Firewall bypass | ⚠️ Phase 2 | ⚠️ Phase 2 | ⚠️ Phase 2 | ✅ TCP 443 | ✅ Built-in | ❌ UDP only |

**Legend**:
- ✅ Excellent fit
- ⚠️ Acceptable with caveats
- ❌ Poor fit or not applicable

---

## Firewall Bypass Capability

### Ranking (Best to Worst)

1. **Outline VPN** (95% bypass rate)
   - Designed specifically for censorship circumvention
   - Shadowsocks protocol obfuscates traffic
   - Works over TCP (can use port 443)
   - Deep packet inspection resistant

2. **OpenVPN + stunnel on TCP 443** (90% bypass rate)
   - Can disguise as HTTPS traffic
   - TCP fallback when UDP blocked
   - Well-tested in restrictive environments
   - Slower than WireGuard

3. **WireGuard + obfuscation wrapper** (85% bypass rate)
   - Can wrap WireGuard in TLS (stunnel/shadowsocks)
   - Fast when not obfuscated
   - 10-20% performance overhead when obfuscated
   - Requires additional setup

4. **Tailscale / WireGuard + Headscale** (70% bypass rate)
   - Excellent NAT traversal (DERP relays)
   - UDP dependency (blocked by some firewalls)
   - WireGuard protocol detectable by DPI
   - Works in most networks, not all

5. **ZeroTier** (65% bypass rate)
   - Good NAT traversal (planetary network)
   - Custom protocol (detectable by DPI)
   - UDP only (blocked by strict firewalls)
   - Works in moderate restrictive networks

6. **Nebula** (50% bypass rate)
   - Limited NAT traversal
   - UDP only (no TCP fallback)
   - Requires lighthouse servers
   - Best for controlled environments

7. **Raw WireGuard** (40% bypass rate)
   - No NAT traversal (manual endpoint config)
   - UDP only
   - Easily blocked by protocol signature
   - Best for peer-to-peer on stable networks

---

## Performance Benchmarks

### Throughput (Typical)

| VPN Solution | Theoretical Max | Real-World (100 Mbps) | Real-World (1 Gbps) |
|--------------|----------------|----------------------|---------------------|
| **WireGuard** | 1000+ Mbps | 95 Mbps | 950 Mbps |
| **Nebula** | 800 Mbps | 80 Mbps | 750 Mbps |
| **ZeroTier** | 500 Mbps | 50 Mbps | 480 Mbps |
| **Outline VPN** | 400 Mbps | 40 Mbps | 380 Mbps |
| **OpenVPN** | 250 Mbps | 25 Mbps | 240 Mbps |

*Note: Real-world performance depends on CPU, network conditions, and configuration*

### Latency Added (vs Direct Connection)

| VPN Solution | Added Latency | Notes |
|--------------|---------------|-------|
| **WireGuard** | +5-10 ms | Kernel-level, minimal overhead |
| **Nebula** | +8-15 ms | Efficient user-space implementation |
| **ZeroTier** | +10-20 ms | Planetary network routing |
| **Outline VPN** | +15-30 ms | Shadowsocks proxy overhead |
| **OpenVPN** | +20-40 ms | User-space, more complex protocol |

### CPU Usage (Single Core, Saturated Link)

| VPN Solution | CPU % | Notes |
|--------------|-------|-------|
| **WireGuard** | 5-10% | Kernel-level, highly optimized |
| **Nebula** | 10-15% | Efficient Go implementation |
| **ZeroTier** | 15-20% | More complex routing logic |
| **Outline VPN** | 20-25% | Shadowsocks encryption overhead |
| **OpenVPN** | 30-40% | Older codebase, user-space |

---

## Cost Comparison (Monthly)

### Self-Hosted on AWS (4 hrs/day usage)

| Solution | Instance Type | Cost/Month | Notes |
|----------|---------------|------------|-------|
| **WireGuard + Headscale** | t3.micro | $9.35 | On-demand, auto-stop |
| **ZeroTier** | t3.micro | $9.35 | On-demand, auto-stop |
| **OpenVPN** | t3.small | $14.40 | Needs more CPU |
| **Outline VPN** | t3.micro | $9.35 | On-demand, auto-stop |
| **Nebula** | t3.micro | $9.35 | On-demand, auto-stop |

### SaaS Options

| Solution | Free Tier | Paid Plan |
|----------|-----------|-----------|
| **Tailscale** | 100 devices, 3 users | $6/user/month |
| **ZeroTier** | 25 devices | $5/device/month (>25) |
| **NordVPN** | N/A | $12.99/month |
| **ExpressVPN** | N/A | $12.95/month |
| **Mullvad** | N/A | €5/month |

---

## Security Comparison

### Encryption Algorithms

| Solution | Cipher | Key Exchange | Authentication |
|----------|--------|--------------|----------------|
| **WireGuard** | ChaCha20-Poly1305 | Curve25519 | BLAKE2s |
| **ZeroTier** | Salsa20/12 | Curve25519 | SHA-384 |
| **OpenVPN** | AES-256-GCM | RSA-2048/ECDH | HMAC SHA-256 |
| **Outline VPN** | AES-256-GCM | N/A (PSK) | HMAC SHA-1 |
| **Nebula** | AES-256-GCM | ECDH P-256 | Ed25519 |

### Security Audit Status

| Solution | Last Audit | Findings | Status |
|----------|------------|----------|--------|
| **WireGuard** | 2019 | Minor issues fixed | ✅ Audited |
| **ZeroTier** | N/A | Community reviewed | ⚠️ Not formally audited |
| **OpenVPN** | 2017 | Several issues fixed | ✅ Audited |
| **Outline VPN** | N/A | Google reviewed | ⚠️ Not formally audited |
| **Nebula** | N/A | Slack/Defined reviewed | ⚠️ Not formally audited |

---

## Decision Matrix for ZeroTeir

### Phase 1: Base VPN (Choose 1)

| Criteria Weight | WireGuard + Headscale | ZeroTier | OpenVPN |
|-----------------|----------------------|----------|---------|
| Performance (30%) | 10 × 0.3 = 3.0 | 7 × 0.3 = 2.1 | 5 × 0.3 = 1.5 |
| Ease of Setup (20%) | 8 × 0.2 = 1.6 | 6 × 0.2 = 1.2 | 4 × 0.2 = 0.8 |
| Self-Hosting (15%) | 10 × 0.15 = 1.5 | 10 × 0.15 = 1.5 | 10 × 0.15 = 1.5 |
| macOS Integration (15%) | 9 × 0.15 = 1.35 | 7 × 0.15 = 1.05 | 7 × 0.15 = 1.05 |
| NAT Traversal (10%) | 9 × 0.1 = 0.9 | 9 × 0.1 = 0.9 | 3 × 0.1 = 0.3 |
| Security (10%) | 10 × 0.1 = 1.0 | 8 × 0.1 = 0.8 | 8 × 0.1 = 0.8 |
| **Total Score** | **9.35** | **7.55** | **5.95** |

**Winner**: WireGuard + Headscale (9.35/10)

### Phase 2: Obfuscation Layer (Optional)

| Solution | Integration Difficulty | Performance Impact | Bypass Rate |
|----------|------------------------|-------------------|-------------|
| **stunnel** | Easy (TLS wrapper) | 10-15% overhead | 90% |
| **shadowsocks** | Moderate (SOCKS5 proxy) | 15-20% overhead | 85% |
| **obfs4** | Moderate (Tor transport) | 20-25% overhead | 95% |
| **v2ray/xray** | Complex (advanced proxy) | 15-25% overhead | 95% |

**Recommendation**: stunnel (simplest, best performance/complexity ratio)

---

## ZeroTier-Specific Notes

### Why NOT ZeroTier (despite project name)?

The project is named "ZeroTeir" (intentional misspelling) but uses **WireGuard + Headscale**:

1. **Performance**: WireGuard is 2x faster (1000 vs 500 Mbps)
2. **Maturity**: WireGuard in Linux kernel since 2020, battle-tested
3. **Simplicity**: WireGuard has ~4000 lines of code vs ZeroTier's ~50k
4. **macOS Integration**: Better native library support (WireGuardKit)
5. **Community**: Larger developer community, more examples

**However, ZeroTier advantages**:
- Planetary network concept (no central server needed)
- More sophisticated mesh networking
- Better for multi-site networks (not our use case)

---

## Tailscale vs Headscale

### Why Headscale over Managed Tailscale?

| Aspect | Headscale (Self-Hosted) | Tailscale (SaaS) |
|--------|------------------------|------------------|
| **Cost** | Free (AWS infrastructure only) | Free tier: 100 devices, 3 users |
| **Privacy** | Full control, no metadata sharing | Tailscale sees connection metadata |
| **Customization** | Full access to control plane | Limited to Tailscale's features |
| **Maintenance** | Self-managed updates | Automatic updates |
| **DERP Relays** | Self-hosted or Tailscale's public relays | Global DERP relay network |
| **ACLs** | Full control | Full control (via Tailscale admin) |

**Decision**: Headscale for Phase 1 (privacy, cost, learning), can migrate to Tailscale SaaS later if desired

---

## Summary Recommendations

### For ZeroTeir Project

1. **Phase 1** (MVP): WireGuard + Headscale
   - Best performance/ease ratio
   - Self-hosted, full control
   - Works in 70% of networks

2. **Phase 2** (Stealth): Add stunnel wrapper
   - Toggle in UI: "Normal Mode" vs "Stealth Mode"
   - Works in 90% of networks
   - 10-15% performance penalty when enabled

3. **Phase 3** (Alternative): Add Outline VPN backend
   - User can switch between WireGuard and Outline
   - Maximum compatibility (95% of networks)
   - Increased complexity, only if needed

### For Different Use Cases

- **Maximum Speed**: Raw WireGuard (peer-to-peer)
- **Easy Setup (SaaS OK)**: Tailscale managed
- **Corporate Firewall**: OpenVPN on TCP 443 or Outline VPN
- **Mesh Network**: ZeroTier or Nebula
- **Privacy-First**: WireGuard + Headscale (self-hosted)

---

**Document Version**: 1.0
**Last Updated**: 2026-02-21
**See Also**: RESEARCH.md for detailed analysis


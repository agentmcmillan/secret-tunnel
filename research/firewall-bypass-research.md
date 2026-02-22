# Firewall Bypass & Censorship Resistance: VPN Technologies Research (2025-2026)

> Research compiled February 2026. Covers the current state of VPN technologies focused on firewall bypass and censorship resistance.

---

## Table of Contents

1. [Firewall/Blocking Bypass Techniques Ranked by Effectiveness](#1-firewallblocking-bypass-techniques-ranked-by-effectiveness)
2. [VPN Solutions and Their Native Bypass Capabilities](#2-vpn-solutions-and-their-native-bypass-capabilities)
3. [Recommended Stack for Maximum Firewall Bypass](#3-recommended-stack-for-maximum-firewall-bypass)
4. [AWS-Specific Considerations](#4-aws-specific-considerations)

---

## 1. Firewall/Blocking Bypass Techniques Ranked by Effectiveness

Ranked from most effective (hardest to block) to least effective against modern firewalls and DPI systems.

### Tier 1: Near-Undetectable (Defeats Advanced DPI)

#### 1. Xray/V2Ray VLESS + Reality/XTLS

- **Effectiveness: Excellent** -- state-of-the-art as of 2025-2026
- VLESS with the Reality protocol is the current gold standard for censorship resistance. It disguises proxy traffic as legitimate TLS 1.3 connections to real websites, making detection extremely difficult even for advanced DPI.
- XTLS (Xray Transport Layer Security) can splice real TLS connections, meaning the traffic is genuinely indistinguishable from normal HTTPS at the protocol level.
- The Reality protocol eliminates the need for a domain or TLS certificate -- it "borrows" the TLS fingerprint of a legitimate site (e.g., microsoft.com).
- Xray-core is more actively maintained than V2Ray-core. Most tools advertising "V2Ray support" actually use Xray under the hood.
- **DPI resistance:** Extremely high. Even China's GFW struggles to reliably detect VLESS+Reality traffic. The traffic has no distinguishable fingerprint because it IS real TLS.
- Management UIs like 3X-UI make deployment straightforward.

**Sources:**
- [Xray-core on GitHub](https://github.com/XTLS/Xray-core)
- [Anti-Censorship Solutions (Xray DeepWiki)](https://deepwiki.com/XTLS/Xray-examples/3-anti-censorship-solutions)
- [Personal proxy setup with 3X-UI and Reality (Habr)](https://habr.com/en/articles/990542/)

#### 2. Trojan Protocol (TLS-based)

- **Effectiveness: Excellent**
- Routes encrypted traffic through port 443, making it blend with regular HTTPS browsing.
- Requires a valid TLS certificate and domain, which adds some setup complexity but also adds legitimacy.
- Widely used and battle-tested in China, Iran, and Russia.
- **DPI resistance:** Very high. Traffic is genuine TLS to a real domain. Censors would need to block the domain itself.

#### 3. Hysteria 2 (QUIC-based)

- **Effectiveness: Very Good**
- Next-generation proxy built on QUIC/HTTP/3 and UDP, designed specifically to defeat DPI.
- Uses genuine TLS certificates, and its Salamander obfuscation layer further disguises traffic signatures.
- Extremely fast due to UDP foundation and QUIC's built-in congestion control.
- **DPI resistance:** High. Looks like standard QUIC/HTTP/3 traffic. However, some countries (Iran) have temporarily blocked all QUIC traffic, and China has partially blocked Hysteria 2 depending on region and provider.
- The reliance on QUIC can be a weakness if a censor simply blocks all QUIC/UDP traffic.

**Sources:**
- [Hysteria 2 on GitHub](https://github.com/apernet/hysteria)
- [Bypassing Censorship with Hysteria 2 (AmbientNode)](https://ambientnode.uk/bypassing-censorship-in-the-age-of-dpi-a-stealth-tunnel-with-hysteria-2/)

### Tier 2: Very Effective (Defeats Most Firewalls)

#### 4. TLS Tunneling / HTTPS Wrapping (wstunnel, stunnel)

- **Effectiveness: Very Good**
- Wraps arbitrary traffic (including WireGuard UDP) inside a WebSocket or HTTP/2 stream with TLS on top.
- wstunnel specifically encapsulates any IP flow (TCP, UDP, SOCKS) inside WebSocket (wss://) so the outer traffic looks like ordinary browser HTTPS traffic.
- Port 443 is virtually never blocked because that would break the web.
- **DPI resistance:** Good to very good. The outer layer is genuine TLS. However, traffic analysis (session duration, volume patterns) can flag tunneled connections. Advanced DPI may detect WebSocket upgrade headers.
- Ideal for wrapping WireGuard in environments where its UDP protocol is blocked.

**Sources:**
- [wstunnel on GitHub](https://github.com/erebe/wstunnel)
- [WireGuard through wstunnel (computerscot)](https://computerscot.github.io/wireguard-through-wstunnel.html)
- [Tunneling WireGuard over HTTPS using Wstunnel (Guido Kroon)](https://kroon.email/site/en/posts/2025/10/wireguard-wstunnel/)

#### 5. Shadowsocks (and Outline VPN)

- **Effectiveness: Good** (declining against the most advanced censors)
- Lightweight SOCKS5 proxy with encryption (ChaCha20-Poly1305 by default in Outline).
- No handshake pattern -- encrypted from the first byte, which historically made it hard to fingerprint.
- Outline VPN (by Jigsaw/Google) wraps Shadowsocks in a user-friendly package and serves ~30 million users monthly.
- **DPI resistance:** Moderate and declining. Originally very effective, but China's GFW and other advanced DPI systems have developed methods to detect Shadowsocks traffic patterns. Outline is adding Shadowsocks-over-WebSockets to counter this.
- Still effective against less sophisticated firewalls (corporate networks, schools, many countries).

**Sources:**
- [Outline VPN](https://getoutline.org/)
- [Shadowsocks Review 2026 (WizCase)](https://www.wizcase.com/reviews/shadowsocks/)
- [Evolving Outline (Jigsaw/Medium)](https://medium.com/jigsaw/evolving-outline-to-power-our-providers-5dfb1820e0a8)

#### 6. QUIC-based Tunneling (Mullvad QUIC Obfuscation)

- **Effectiveness: Good**
- Transmits WireGuard traffic through the QUIC transport layer so it looks like ordinary HTTP/3 traffic.
- Mullvad VPN rolled out QUIC obfuscation for WireGuard in September 2025 for desktop, and 2025.8 for mobile.
- NordVPN is adding QUIC support via its NordWhisper technology.
- **DPI resistance:** Good. QUIC is widely used (Google, YouTube, etc.) so blocking it entirely has large collateral damage. However, some censors (Iran, partially China) have shown willingness to throttle or block QUIC.

**Sources:**
- [Mullvad QUIC Obfuscation Blog](https://mullvad.net/en/blog/2025/9/9/introducing-quic-obfuscation-for-wireguard)
- [Mullvad mobile QUIC (TechRadar)](https://www.techradar.com/vpn/vpn-services/mobile-mullvad-vpn-users-gain-quic-enabled-censorship-bypass)

#### 7. obfs4 (Tor Pluggable Transport)

- **Effectiveness: Good**
- Designed specifically for Tor but can be used independently.
- Makes traffic look like random noise -- no identifiable protocol fingerprint.
- Well-tested against the GFW but its bridge addresses can be enumerated and blocked.
- **DPI resistance:** Good against protocol fingerprinting. Vulnerable to active probing attacks where the censor connects to the suspected bridge to verify.

### Tier 3: Moderate (Works Against Basic Firewalls)

#### 8. TCP Fallback on Port 443 (HTTPS impersonation)

- **Effectiveness: Moderate**
- Many VPN tools (ZeroTier, OpenVPN) can fall back to TCP on port 443.
- Gets through basic port-based firewalls since 443 is always allowed.
- **DPI resistance:** Low to moderate. The TLS handshake and traffic patterns of VPN-over-443 differ from real HTTPS. OpenVPN on port 443 has a well-known fingerprint that is trivially detected by DPI. ZeroTier's TCP fallback imitates TLS frames but is not true TLS.

#### 9. UDP Hole Punching

- **Effectiveness: Moderate** (not a bypass technique per se)
- Used by WireGuard, ZeroTier, Tailscale, Nebula to establish direct peer-to-peer connections through NATs.
- Works well for NAT traversal but does NOT bypass firewalls that block UDP or use DPI.
- If the firewall blocks the specific UDP port, or blocks all non-standard UDP traffic, hole punching fails.
- **DPI resistance:** None. The underlying protocol (WireGuard, ZeroTier) is visible to DPI.

#### 10. Domain Fronting

- **Effectiveness: Poor** (largely defunct as of 2025)
- Historically used to hide the true destination by routing through a CDN, putting one domain in the SNI and another in the HTTP Host header.
- **Major CDNs have blocked it:** Cloudflare (2015), Amazon (2018), Google (2018), Microsoft (2022), Fastly (2024).
- May still work on smaller or misconfigured CDN providers, but finding frontable domains is unreliable.
- **DPI resistance:** Was excellent when it worked, since traffic appeared to go to a legitimate high-reputation domain. Now largely irrelevant.

**Sources:**
- [Domain Fronting (Compass Security)](https://blog.compass-security.com/2025/03/bypassing-web-filters-part-3-domain-fronting/)
- [Domain Fronting (Wikipedia)](https://en.wikipedia.org/wiki/Domain_fronting)

### DPI Resistance Summary Table

| Technique | Port-based Firewall | Stateful Firewall | Basic DPI | Advanced DPI (GFW-level) |
|-----------|---------------------|--------------------|-----------|--------------------------|
| VLESS + Reality | Bypasses | Bypasses | Bypasses | Bypasses |
| Trojan | Bypasses | Bypasses | Bypasses | Mostly bypasses |
| Hysteria 2 | Bypasses | Bypasses | Bypasses | Partially blocked |
| wstunnel/TLS wrap | Bypasses | Bypasses | Bypasses | Detectable via traffic analysis |
| Shadowsocks | Bypasses | Bypasses | Mostly bypasses | Increasingly detected |
| QUIC tunneling | Bypasses | Bypasses | Bypasses | Can be blanket-blocked |
| obfs4 | Bypasses | Bypasses | Bypasses | Vulnerable to active probing |
| TCP on 443 | Bypasses | Bypasses | Detected | Detected |
| UDP hole punch | Fails if UDP blocked | Fails | N/A | N/A |
| Domain fronting | Bypasses | Bypasses | Bypasses | N/A (defunct) |

---

## 2. VPN Solutions and Their Native Bypass Capabilities

### WireGuard

- **Protocol:** Raw UDP only (default port 51820)
- **Native bypass capability:** None. WireGuard has a well-known protocol fingerprint and uses UDP exclusively.
- **Firewall status:** Blocked by any firewall that filters non-standard UDP. Trivially identified by DPI.
- **Bypass strategy:** Must be wrapped in another transport. Best options:
  - wstunnel (WebSocket over TLS) -- wraps WireGuard UDP in wss:// on port 443
  - Mullvad QUIC obfuscation -- wraps WireGuard in QUIC
  - Phantun -- masks UDP as TCP/ICMP
- **Strengths:** Extremely fast, minimal overhead, excellent cryptography, tiny codebase. The best VPN protocol IF you can get the packets through.

### ZeroTier

- **Protocol:** UDP with TCP fallback
- **Native bypass capability:** Moderate
  - Primary: UDP hole punching for peer-to-peer connections through NATs
  - Fallback: TCP relay through root servers on port 443, imitating TLS frames
  - Custom "moons" (private root servers) can be deployed for dedicated relay infrastructure
- **Firewall status:** Works through most NATs and basic firewalls. The TCP fallback on 443 gets through port-based filters. However, the TCP relay is NOT true TLS and can be detected by advanced DPI.
- **Strengths:** Easy setup, virtual L2 network, works well for mesh networking use cases.
- **Weaknesses:** TCP fallback adds latency; relay servers see encrypted payloads but handle routing; not designed for censorship resistance.

**Sources:**
- [ZeroTier TCP Relay Documentation](https://docs.zerotier.com/relay/)
- [ZeroTier Corporate Firewalls](https://docs.zerotier.com/corporate-firewalls/)

### Tailscale / Headscale

- **Protocol:** WireGuard (UDP) with DERP relay fallback
- **Native bypass capability:** Good
  - Primary: Direct WireGuard connections with NAT traversal
  - Fallback: DERP (Designated Encrypted Relay for Packets) servers over HTTPS on port 443
  - Any device that can open an HTTPS connection can build a tunnel via DERP
  - New in October 2025: Tailscale Peer Relays as an alternative to DERP, hostable on your own infrastructure
- **Firewall status:** DERP relays use genuine HTTPS, making them more resistant to DPI than ZeroTier's TCP fallback. Works through most corporate firewalls.
- **Headscale:** Open-source, self-hosted Tailscale control server. Supports custom DERP server configuration. Lets you run the entire infrastructure yourself.
- **Strengths:** Excellent user experience, MagicDNS, ACLs, SSO integration. DERP is a legitimate fallback that works in most restricted environments.
- **Weaknesses:** DERP relays add latency; WireGuard traffic is still identifiable when direct connections are used; not specifically designed for censorship resistance.

**Sources:**
- [Tailscale DERP Documentation](https://tailscale.com/kb/1232/derp-servers)
- [Tailscale Peer Relays](https://tailscale.com/kb/1591/peer-relays)
- [Headscale DERP Configuration](https://headscale.net/stable/ref/derp/)

### Outline VPN

- **Protocol:** Shadowsocks (SOCKS5 proxy with ChaCha20-Poly1305 encryption)
- **Native bypass capability:** Good
  - Designed from the ground by Jigsaw (Google) specifically for censorship resistance
  - Resistant to DNS blocking, content blocking, and IP blocking
  - No distinctive handshake pattern (encrypted from first byte)
  - Adding Shadowsocks-over-WebSockets for additional obfuscation
- **Firewall status:** Works where many commercial VPNs fail. Users in Iran, China, and Russia report success, though effectiveness varies by region and is declining against the most advanced DPI.
- **Strengths:** Very easy to deploy and manage. One-click server setup. Client apps for all platforms. ~30 million monthly users.
- **Weaknesses:** Shadowsocks is increasingly fingerprinted by advanced DPI. Single-hop architecture. Not as stealthy as VLESS+Reality.

**Sources:**
- [Outline VPN](https://getoutline.org/)
- [Self-hosting Shadowsocks with Outline (Jonah Aragon)](https://www.jonaharagon.com/posts/self-hosting-shadowsocks-vpn-outline/)

### Nebula (by Slack)

- **Protocol:** UDP (default port 4242), Noise Protocol Framework
- **Native bypass capability:** Low
  - Uses UDP hole punching via "lighthouse" discovery nodes
  - No TCP fallback or TLS wrapping built in
  - Certificate-based mutual authentication (Elliptic-curve Diffie-Hellman + AES-256-GCM)
- **Firewall status:** Works through NATs via hole punching. Fails against firewalls that block UDP. Not designed for censorship resistance.
- **Strengths:** Excellent security model, fully decentralized (no relay infrastructure needed if hole punching works), performant.
- **Weaknesses:** UDP only, no obfuscation, no fallback mechanism.

**Sources:**
- [Nebula on GitHub](https://github.com/slackhq/nebula)
- [Nebula Documentation](https://nebula.defined.net/docs/)

### Netmaker

- **Protocol:** WireGuard-based mesh networking
- **Native bypass capability:** Low
  - Uses WireGuard under the hood, inheriting its UDP-only limitation
  - Has relay server functionality for nodes that cannot establish direct connections
  - No built-in obfuscation or TLS wrapping
- **Firewall status:** Same as raw WireGuard -- blocked by UDP-filtering firewalls, detectable by DPI.
- **Strengths:** Automated WireGuard mesh management, Kubernetes integration, good admin UI.
- **Weaknesses:** No censorship resistance features.

### OpenVPN

- **Protocol:** UDP or TCP (configurable)
- **Native bypass capability:** Moderate
  - Can run in TCP mode on port 443
  - Has built-in TLS layer for the control channel
  - Supports obfuscation plugins (XOR patch, obfs-proxy)
- **Firewall status:** TCP on port 443 gets through basic firewalls. However, OpenVPN has one of the most well-known protocol fingerprints in the VPN world. Advanced DPI trivially identifies OpenVPN traffic regardless of port.
- **Strengths:** Mature, widely supported, highly configurable, extensive audit history.
- **Weaknesses:** Well-known fingerprint, slower than WireGuard, complex configuration. Actively blocked by China, Russia, Iran, and many corporate firewalls.

### Comparison Table

| Solution | Protocol | UDP Hole Punch | TCP/TLS Fallback | DPI Resistance | Censorship Design |
|----------|----------|----------------|-------------------|----------------|-------------------|
| WireGuard | UDP | No (needs NAT tool) | No (needs wrapper) | None | No |
| ZeroTier | UDP + TCP | Yes | Yes (port 443) | Low | No |
| Tailscale | WireGuard | Yes | Yes (DERP/HTTPS) | Moderate | No |
| Outline | Shadowsocks | No | N/A (TCP-based) | Good (declining) | **Yes** |
| Nebula | UDP | Yes | No | None | No |
| Netmaker | WireGuard | Yes (via WG) | Relay only | None | No |
| OpenVPN | UDP/TCP | No | Yes (port 443) | Low | No |

---

## 3. Recommended Stack for Maximum Firewall Bypass

### Option A: Maximum Stealth (Defeats GFW-level DPI)

**Stack: Xray + VLESS + Reality + XTLS-Vision**

```
Client --> Xray Client (VLESS+Reality) --> [Looks like TLS to microsoft.com] --> Xray Server --> Internet
```

- **Why:** This is the most DPI-resistant option available in 2025-2026. Reality borrows TLS fingerprints from legitimate sites, making traffic genuinely indistinguishable from normal HTTPS. No domain or certificate needed.
- **Setup complexity:** Medium. Use 3X-UI panel for web-based management.
- **Performance:** Very good. XTLS-Vision splices TLS connections with minimal overhead.
- **Best for:** Users facing state-level censorship (China, Russia, Iran).
- **Downside:** This is a proxy, not a full VPN. You get SOCKS/HTTP proxy functionality, not a tunnel for all traffic. You can route specific apps through it (with tun2socks for full tunnel), but it requires more client-side configuration than a VPN.

### Option B: Full VPN with Stealth (Best Balanced Approach)

**Stack: WireGuard + wstunnel (WebSocket over TLS)**

```
Client --> wstunnel client --> [wss:// on port 443, looks like HTTPS] --> wstunnel server --> WireGuard server --> Internet
```

- **Why:** Gets you a proper full-tunnel VPN (WireGuard) with all traffic routed through it, wrapped in genuine TLS WebSocket traffic on port 443.
- **Setup complexity:** Medium. Requires running both wstunnel and WireGuard on the server.
- **Performance:** Good. WireGuard is fast; wstunnel adds some overhead from the TLS/WebSocket layer and TCP-over-UDP encapsulation (potential TCP meltdown).
- **Best for:** Users who need a full VPN tunnel through corporate or national firewalls, and who face moderate DPI.
- **Downside:** Advanced DPI can potentially detect long-lived WebSocket connections with high throughput as anomalous. Not as stealthy as VLESS+Reality.

### Option C: Maximum Simplicity

**Stack: Outline VPN**

```
Client (Outline app) --> [Shadowsocks on custom port] --> Outline Server --> Internet
```

- **Why:** One-click server deployment on any cloud provider. Polished client apps for all platforms. Designed for journalists and activists.
- **Setup complexity:** Very low. DigitalOcean/AWS one-click deploy.
- **Performance:** Good.
- **Best for:** Users who need something that "just works" and face moderate censorship. Great for sharing access with non-technical users via access keys.
- **Downside:** Shadowsocks is increasingly detected by advanced DPI. Not recommended as sole tool against GFW-level censorship in 2025-2026.

### Option D: Defense in Depth (Multiple Fallbacks)

**Stack: Layered approach with fallback chain**

```
Primary:    WireGuard direct (UDP) -- fastest, use when not blocked
Fallback 1: WireGuard + wstunnel (WSS on 443) -- when UDP is blocked
Fallback 2: Xray VLESS+Reality -- when DPI detects tunneled traffic
Emergency:  Outline VPN on a fresh IP -- when all else fails, spin up new server
```

- **Why:** No single technique works everywhere all the time. State censors are deploying AI-enhanced DPI (Russia's Roskomnadzor plans for 2026). Having multiple independent tools with different traffic signatures maximizes your chances.
- **Setup complexity:** High. Requires maintaining multiple server configurations.
- **Best for:** Users in the most restrictive environments who need guaranteed connectivity.

### Specific Recommendations by Use Case

| Use Case | Recommended Stack | Notes |
|----------|-------------------|-------|
| Corporate firewall bypass | WireGuard + wstunnel | WSS on 443 gets through almost any corporate firewall |
| China / GFW | Xray VLESS + Reality | Gold standard. Rotate server IPs periodically |
| Russia (2026) | Xray VLESS + Reality, with Hysteria 2 backup | AI-enhanced DPI coming; keep multiple options |
| Iran | VLESS + Reality or Hysteria 2 | Iran blocks QUIC periodically; have TCP backup |
| General censorship | Outline VPN | Simplest setup, good enough for most countries |
| Hotel/airport Wi-Fi | WireGuard + wstunnel or Tailscale DERP | DERP is zero-config if already using Tailscale |
| Mesh network through firewalls | Tailscale/Headscale | DERP handles fallback automatically |

---

## 4. AWS-Specific Considerations

### Ports and Protocols

- **Port 443 (TCP):** Always works. This is your safest bet for any tunneled VPN traffic. AWS security groups allow any port configuration on EC2.
- **UDP ports:** Fully supported on EC2. No restrictions on WireGuard (51820), QUIC (443), or any custom UDP port from the AWS side.
- **All protocols:** AWS does not restrict VPN protocols on EC2 instances. You can run WireGuard, OpenVPN, Shadowsocks, Xray, or anything else without issue.
- **AWS-side restrictions:** The only limitations are your security group rules and NACLs, which you control.

### AWS Service-Specific Notes

- **EC2:** Full flexibility. You control the OS, ports, and protocols. Best for custom VPN setups.
- **Lightsail:** Simplified EC2 alternative. Same flexibility but with bundled bandwidth (cheaper for VPN use cases).
- **AWS Client VPN:** Managed OpenVPN service, supports ports 443 and 1194 (TCP/UDP). Not useful for censorship resistance due to OpenVPN's detectable fingerprint.
- **Site-to-Site VPN:** IPsec-based, uses UDP 500 (IKE) and UDP 4500 (NAT-T). Not relevant for censorship bypass.

### Cost Breakdown (as of 2025-2026)

#### EC2

| Component | Cost | Notes |
|-----------|------|-------|
| t3.micro instance | ~$7.60/month | Sufficient for 1-10 VPN users |
| t3.nano instance | ~$3.80/month | Sufficient for 1-3 users |
| Data transfer OUT | $0.09/GB (first 10TB) | **This is the main cost driver** |
| Data transfer IN | Free | |
| Elastic IP (attached) | Free | Free while instance is running |
| Elastic IP (detached) | $0.005/hour | ~$3.65/month if not attached |

**Typical monthly cost for a personal VPN:**
- Light use (50GB/month): ~$4 (instance) + ~$4.50 (data) = **~$8.50/month**
- Heavy use (500GB/month): ~$4 (instance) + ~$45 (data) = **~$49/month**

#### Lightsail (Recommended for VPN)

| Plan | Cost | Bandwidth Included | Notes |
|------|------|--------------------|-------|
| 512MB RAM, 1 vCPU | $3.50/month | 1 TB | Best value for personal VPN |
| 1GB RAM, 1 vCPU | $5/month | 2 TB | Good for small team |
| 2GB RAM, 1 vCPU | $10/month | 3 TB | Comfortable headroom |

**Lightsail is typically 3-5x cheaper than EC2 for VPN use** because bandwidth is bundled. A $3.50/month Lightsail instance with 1TB bandwidth is equivalent to ~$90+ on EC2.

#### Free Tier

- **EC2 t2.micro/t3.micro:** 750 hours/month free for 12 months (new accounts only, legacy tier before July 2025).
- **Lightsail:** First 3 months free on the $3.50 plan.

### Recommended AWS Architecture

```
                    Internet
                       |
              +--------+--------+
              |  AWS Lightsail   |
              |  $3.50-5/month   |
              |                  |
              |  - Xray (VLESS   |
              |    + Reality)    |
              |  - WireGuard     |
              |  - wstunnel      |
              |  - Outline       |
              +------------------+
```

**Recommended setup:**
1. **Lightsail instance** ($3.50-5/month) in a region close to your target users
2. **Primary:** Xray with VLESS+Reality on port 443 (stealth proxy)
3. **Secondary:** WireGuard + wstunnel on a separate port (full tunnel VPN)
4. **Tertiary:** Outline VPN for easy sharing with non-technical users

### AWS Region Selection

Choose regions based on:
- **Proximity to users** for low latency
- **Not blocked by the censor** -- some countries block entire AWS IP ranges
- **Recommended regions for censorship bypass:**
  - `ap-northeast-1` (Tokyo) -- good for East Asia
  - `ap-southeast-1` (Singapore) -- good for Southeast Asia
  - `eu-west-1` (Ireland) -- good for Europe/Middle East
  - `us-east-1` (N. Virginia) -- lowest cost, good general choice

### AWS-Specific Tips

1. **Rotate IPs:** If your server IP gets blocked, release and allocate a new Elastic IP (free while attached). Lightsail allows IP detachment/reattachment as well.
2. **Use multiple regions:** Deploy in 2-3 regions for redundancy. If one region's IP range is blocked, failover to another.
3. **CloudFront as a front:** You can potentially route Xray traffic through CloudFront as a CDN relay, making the traffic appear to come from CloudFront IP ranges (similar to domain fronting but using your own domain).
4. **Avoid AWS-managed VPN services:** AWS Client VPN and Site-to-Site VPN use OpenVPN/IPsec, which are trivially detected. Run your own stack on EC2/Lightsail instead.
5. **Security groups:** Only open the ports you need. For VLESS+Reality on 443, that's just TCP 443 inbound + SSH for management.

---

## Emerging Threats (2026 and Beyond)

### AI-Enhanced DPI

Russia's Roskomnadzor is integrating machine learning models into DPI infrastructure to classify encrypted traffic patterns that resemble VPN connections. This represents a shift from passive blocking to active hunting of VPN traffic using AI.

**Implications:**
- Traffic analysis (volume, timing, session duration) becomes a detection vector even for protocols with perfect cryptographic stealth.
- Countermeasure: Traffic shaping and padding to mimic normal browsing patterns. Xray and Hysteria 2 are developing features in this direction.

### Protocol-Specific Blocking

- Some countries (Iran) have shown willingness to block entire protocols (QUIC) despite collateral damage.
- China continues to refine active probing attacks against suspected proxy servers.
- **Countermeasure:** Multi-protocol fallback chains. Never rely on a single tool.

### IP Range Blocking

- Cloud provider IP ranges (AWS, GCP, Azure, DigitalOcean) are increasingly blocked by state censors.
- **Countermeasure:** Use residential IP addresses, smaller VPS providers, or CDN fronting.

**Sources:**
- [Russia VPN Censorship 2026 (VPNx Blog)](https://vpnx.blog/vpn-censorship/)
- [Global De-Censorship Report 2025 (Medium)](https://saropa-contacts.medium.com/global-de-censorship-report-2025-freedom-protocols-technologies-286a5a6d6281)
- [NymVPN 2026 Update (WebProNews)](https://www.webpronews.com/nymvpn-2026-update-boosts-privacy-and-censorship-evasion/)
- [VPN Restrictions 2026 (RiderChris)](https://riderchris.com/vpn-restrictions-countries-block-vpns-and-how-to-bypass/)
- [QUIC SNI Censorship (USENIX Security 2025)](https://gfw.report/publications/usenixsecurity25/data/paper/quic-sni.pdf)

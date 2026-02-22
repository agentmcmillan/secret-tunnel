# Architectural Decision Records (ADR)

Key technical decisions made during ZeroTeir planning and development.

**Format**: Lightweight ADRs for rapid decision tracking.

---

## ADR-001: VPN Protocol Selection

**Date**: 2026-02-21
**Status**: Accepted
**Deciders**: Planning team

### Context

Need to choose VPN protocol for ZeroTeir on-demand VPN system. Requirements:
- High performance (streaming, browsing)
- Self-hostable on AWS
- Good macOS support
- Reasonable NAT traversal
- Cost-effective

### Decision

Use **WireGuard** as the VPN protocol with **Headscale** as the control plane.

### Rationale

**WireGuard Advantages**:
- Performance: 1000+ Mbps (4x faster than OpenVPN, 2x faster than ZeroTier)
- Security: Modern cryptography (ChaCha20-Poly1305, Curve25519)
- Simplicity: ~4000 lines of code vs 50k+ for alternatives
- Maturity: In Linux kernel since 2020
- macOS Support: Official WireGuardKit Swift library

**Headscale Advantages**:
- Self-hosted (no SaaS dependency, full privacy)
- Tailscale-compatible (proven architecture)
- Open source (BSD 3-Clause)
- Excellent NAT traversal (DERP relay protocol)
- Clean API for automation

**Alternatives Considered**:
- ZeroTier: Slower (500 Mbps), more complex protocol
- OpenVPN: Legacy, 4x slower, harder to automate
- Tailscale (SaaS): Privacy concerns, SaaS dependency
- Nebula: Poor NAT traversal, smaller community

### Consequences

**Positive**:
- Fast VPN performance (minimal overhead)
- Self-hosted maintains privacy goal
- Good macOS integration via WireGuardKit
- Large community for troubleshooting

**Negative**:
- UDP dependency (may be blocked by restrictive firewalls)
- WireGuard protocol detectable by DPI (mitigated in Phase 2)

**Mitigations**:
- Phase 2: Add stunnel/shadowsocks wrapper for TCP 443 fallback
- Phase 3: Add Outline VPN as alternative backend if needed

---

## ADR-002: Infrastructure as Code Tool

**Date**: 2026-02-21
**Status**: Accepted

### Context

Need IaC tool to manage AWS infrastructure (EC2, Lambda, API Gateway, CloudWatch).

### Decision

Use **Terraform** (not AWS CDK).

### Rationale

**Terraform Advantages**:
- Declarative (easier to reason about state)
- Cloud-agnostic (could support GCP/Azure in future)
- Better for simple infrastructure (EC2 + networking)
- More examples for VPN server deployments
- HCL syntax simpler than TypeScript for this use case

**CDK Considerations**:
- Overkill for this infrastructure complexity
- TypeScript/Python adds dependency
- Steeper learning curve
- Better for complex multi-stack applications (not our use case)

### Consequences

**Positive**:
- Simpler to version control state (S3 backend)
- Easier for non-developers to understand
- More portable across cloud providers

**Negative**:
- Less programmatic (can't use loops, functions as easily)
- Separate language from macOS app (Swift)

---

## ADR-003: macOS Application Framework

**Date**: 2026-02-21
**Status**: Accepted

### Context

Need framework for macOS menu bar application.

### Decision

Use **Swift + SwiftUI** (not Electron).

### Rationale

**Native Advantages**:
- Performance: Better CPU, memory, battery usage
- Size: ~10 MB vs ~100+ MB for Electron
- Integration: Native menu bar, Keychain, Network Extension
- Security: Easier code signing and sandboxing
- UX: Native macOS look and feel

**Electron Considerations**:
- Cross-platform (not needed - macOS only for Phase 1)
- Web technologies (not needed - team knows Swift)
- Larger attack surface

### Consequences

**Positive**:
- Professional, native feel
- Better performance and battery life
- Smaller distribution size
- Access to macOS frameworks (Keychain, Network)

**Negative**:
- Swift knowledge required (not web tech)
- macOS only (no Windows/Linux until rewrite)

---

## ADR-004: Cost Optimization Strategy

**Date**: 2026-02-21
**Status**: Accepted

### Context

AWS costs can escalate if instance runs 24/7. Need strategy to minimize costs.

### Decision

**On-demand instance** with **auto-stop after 60 minutes idle**.

### Rationale

**Cost Model**:
- Instance OFF: $3.60/mo (Elastic IP only)
- Instance ON: +$0.0104/hr (t3.micro)
- Auto-stop reduces monthly cost by 60-80%

**Alternatives Considered**:
- Always-on instance: $10.50/mo instance cost (too high)
- Manual stop: User forgets, costs escalate
- 5-minute warm-up: Small benefit, added complexity

**Implementation**:
- CloudWatch Events (every 5 min) triggers Lambda
- Lambda queries Headscale API for active connections
- Stop instance if all machines idle > 60 min

### Consequences

**Positive**:
- Target cost: <$10/month for typical usage
- No manual intervention needed
- Prevents runaway costs if user forgets

**Negative**:
- 30-60 second cold start on reconnect
- Complexity: Additional Lambda function

**Accepted Trade-off**: Cold start is acceptable for on-demand use case (user expects to wait for instance to start).

---

## ADR-005: Secret Storage

**Date**: 2026-02-21
**Status**: Accepted

### Context

Need to store sensitive credentials (API keys, WireGuard private keys).

### Decision

Store all secrets in **macOS Keychain** (not UserDefaults, not files).

### Rationale

**Keychain Advantages**:
- OS-level encryption (AES-256)
- Protected by user's login password
- Sandboxed (per-application access)
- Backed up by iCloud Keychain (optional)

**Alternatives Rejected**:
- UserDefaults: Plain text, easily readable
- Config files: Might be committed to git
- Custom encryption: Reinventing the wheel, crypto errors

**Secrets to Store**:
- Lambda API Key
- Headscale API Key
- WireGuard Private Key
- Machine ID

### Consequences

**Positive**:
- Best security practice for macOS apps
- User doesn't need to manage encryption
- Prevents accidental leakage

**Negative**:
- Keychain API more complex than UserDefaults
- Debugging harder (can't easily inspect values)

---

## ADR-006: State Management Pattern

**Date**: 2026-02-21
**Status**: Accepted

### Context

Connection process has multiple async steps that can fail. Need clear error handling.

### Decision

Use **explicit state machine** for connection lifecycle.

### Rationale

**States**:
```
DISCONNECTED → STARTING_INSTANCE → WAITING_HEADSCALE →
CONNECTING_TUNNEL → CONNECTED → DISCONNECTING → DISCONNECTED
```

**Benefits**:
- Clear mental model of connection process
- Easy to add timeout handling per state
- Simplifies debugging (log state transitions)
- UI can show specific progress ("Starting instance...", "Connecting tunnel...")

**Alternatives Considered**:
- Async/await with error handling: Less clear what state app is in
- Event-driven: More complex, harder to reason about flow

### Consequences

**Positive**:
- Easier to debug connection issues
- Clear error messages to user
- Simple retry logic (restart from DISCONNECTED)

**Negative**:
- More boilerplate code
- Need to handle all state transitions

---

## ADR-007: WireGuard Integration Approach

**Date**: 2026-02-21
**Status**: Accepted (with caveat)

### Context

Two ways to integrate WireGuard on macOS:
1. Shell out to `wg-quick` command
2. Use WireGuardKit Swift library

### Decision

**Phase 1**: Shell out to `wg-quick` (simpler, faster to implement)
**Phase 2**: Migrate to WireGuardKit if needed (better UX, more control)

### Rationale

**wg-quick Advantages**:
- Faster to implement (just execute command)
- Proven, battle-tested
- Easier to debug (can test manually)

**WireGuardKit Advantages**:
- Native Swift integration
- Better error handling
- No external dependency
- Can use Network Extension (system VPN integration)

**Decision**: Start simple, optimize later if needed.

### Consequences

**Positive**:
- Faster MVP delivery
- Can validate architecture before deep integration

**Negative**:
- May need to rewrite tunnel management later
- `wg-quick` requires installation (Homebrew or bundled)

**Migration Path**: If user experience requires, migrate to WireGuardKit in Phase 2.

---

## ADR-008: DNS Configuration

**Date**: 2026-02-21
**Status**: Accepted

### Context

Two DNS routing options:
1. Route all DNS through VPN (via Headscale MagicDNS)
2. Only use MagicDNS for internal names, leave external DNS direct

### Decision

**Route all DNS through VPN** (set system DNS to 100.64.0.1).

### Rationale

**Privacy Goals**:
- ISP can track browsing via DNS queries
- Public WiFi can intercept DNS
- VPN should provide complete privacy

**Alternatives Considered**:
- Only MagicDNS: Less disruptive but defeats privacy goal
- Split DNS: Complex configuration

**Implementation**:
- Set system DNS resolver to Headscale's IP (100.64.0.1)
- Headscale forwards to public DNS (1.1.1.1, 8.8.8.8)
- Restore original DNS on disconnect

### Consequences

**Positive**:
- Complete DNS privacy (ISP can't track)
- Protects against DNS hijacking

**Negative**:
- Slightly slower DNS resolution (extra hop)
- If VPN drops, DNS breaks (mitigated by disconnect restore)

**Future Enhancement**: Add kill switch option (block all DNS if VPN drops).

---

## ADR-009: Phased Firewall Bypass Approach

**Date**: 2026-02-21
**Status**: Accepted

### Context

Some corporate firewalls block UDP or detect VPN protocols. Need strategy.

### Decision

**Phased approach**:
- **Phase 1**: WireGuard UDP (works in 70% of networks)
- **Phase 2**: Add stunnel TCP 443 wrapper (works in 90% of networks)
- **Phase 3**: Add Outline VPN backend (works in 95% of networks)

### Rationale

**Why Not Build All Upfront**:
- Complexity: stunnel/Outline add significant development time
- Unknown: Don't know yet which networks user will encounter
- YAGNI: Might not need if Phase 1 works everywhere for user

**Why Phased**:
- Deliver value faster (MVP in 4-6 weeks vs 8-10 weeks)
- Learn which networks are problematic
- Can prioritize Phase 2/3 based on real feedback

### Consequences

**Positive**:
- Faster MVP delivery
- Simpler initial implementation
- Can validate architecture first

**Negative**:
- Won't work in all networks initially
- May frustrate user if they hit restrictive network early

**Mitigation**: Document network requirements clearly, set expectations.

---

## ADR-010: Instance Size Selection

**Date**: 2026-02-21
**Status**: Accepted

### Context

Need to choose EC2 instance type for VPN server.

### Decision

Use **t3.micro** (2 vCPU, 1 GB RAM).

### Rationale

**Cost**: $0.0104/hr (~$7.50/mo if always on, <$2/mo for 4 hrs/day)

**Performance**:
- Single user VPN: Minimal CPU (WireGuard in kernel)
- Headscale: Lightweight coordination server
- Network: Up to 5 Gbps burst (more than enough)

**Alternatives Considered**:
- t3.nano: Too small (512 MB RAM), risk of OOM
- t3.small: Overkill (2 GB RAM), 2x cost

**Monitoring**: CloudWatch metrics to verify t3.micro is sufficient.

### Consequences

**Positive**:
- Lowest cost tier that meets requirements
- Burstable CPU good for VPN workload (bursty traffic)

**Negative**:
- If multiple users: May need to upgrade
- CPU credit system (if sustained high CPU, throttles)

**Future**: If metrics show CPU throttling, upgrade to t3.small.

---

## ADR-011: Authentication Strategy

**Date**: 2026-02-21
**Status**: Accepted

### Context

Need to authenticate macOS app to Lambda API and Headscale API.

### Decision

**Multi-layer authentication**:
1. Lambda API: API Key (x-api-key header via API Gateway)
2. Headscale API: Bearer Token (API key generated by Headscale)
3. WireGuard: Public/private key pairs (cryptographic)

### Rationale

**Lambda API Key**:
- Simple to implement (API Gateway built-in)
- No IAM role complexity for client
- Rotating key is easy

**Headscale Bearer Token**:
- Standard API authentication pattern
- Generated by Headscale CLI
- Can be scoped to specific permissions

**WireGuard Keys**:
- Cryptographic authentication (no password)
- Private key never leaves client
- Public key registered with Headscale

**Alternatives Considered**:
- AWS Cognito: Overkill for single-user app
- mTLS: More complex, not needed
- No auth on Lambda: Security risk

### Consequences

**Positive**:
- Defense in depth (multiple layers)
- Each layer uses appropriate mechanism
- Can rotate keys independently

**Negative**:
- User must manage two API keys (Lambda + Headscale)
- More setup complexity

**Mitigation**: Terraform outputs both keys, clear setup docs.

---

## ADR-012: Logging Strategy

**Date**: 2026-02-21
**Status**: Accepted

### Context

Need logging for debugging connection issues.

### Decision

- **macOS App**: OSLog (macOS native logging)
- **Lambda**: CloudWatch Logs (AWS native)
- **EC2**: CloudWatch Agent → CloudWatch Logs

### Rationale

**OSLog**:
- Native macOS logging system
- Viewable in Console.app
- Structured logging (subsystem + category)
- Automatic log rotation

**CloudWatch**:
- AWS-native, no setup needed
- Queryable (CloudWatch Insights)
- Retention policies
- Can create alarms on log patterns

**Log Levels**:
- DEBUG: Verbose (config values, state transitions)
- INFO: Normal operations (connect, disconnect)
- WARN: Recoverable errors (retry logic)
- ERROR: Failures (with stack traces)

### Consequences

**Positive**:
- Easy to debug issues (logs in familiar tools)
- Structured logging enables searching
- Separate logs per component

**Negative**:
- User needs to use Console.app (not in-app)
- CloudWatch has retention costs (mitigated: 30-day retention)

**Future Enhancement**: Add in-app log viewer in Settings (Phase 3).

---

## Summary of Key Decisions

| ADR | Decision | Rationale |
|-----|----------|-----------|
| ADR-001 | WireGuard + Headscale | Fastest, self-hosted, mature |
| ADR-002 | Terraform | Simpler for infrastructure, cloud-agnostic |
| ADR-003 | Swift + SwiftUI | Native performance, better UX |
| ADR-004 | Auto-stop after 60 min | Cost optimization, prevents runaway costs |
| ADR-005 | macOS Keychain | Best practice for secret storage |
| ADR-006 | State machine | Clear error handling, debuggability |
| ADR-007 | wg-quick (Phase 1) | Faster MVP, migrate later if needed |
| ADR-008 | All DNS through VPN | Privacy goal, prevent ISP tracking |
| ADR-009 | Phased firewall bypass | Deliver value faster, add complexity if needed |
| ADR-010 | t3.micro instance | Lowest cost that meets requirements |
| ADR-011 | Multi-layer auth | Defense in depth, appropriate mechanisms |
| ADR-012 | OSLog + CloudWatch | Native tools, structured logging |

---

## Decision Status

- **Accepted**: Decision made and documented
- **Superseded**: Replaced by later decision
- **Deprecated**: No longer valid
- **Proposed**: Under consideration

---

**Document Version**: 1.0
**Last Updated**: 2026-02-21
**Maintained By**: ZeroTeir Team


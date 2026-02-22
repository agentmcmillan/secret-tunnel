# ZeroTeir - VPN On Demand

VPN-on-demand system combining macOS menu bar UI, AWS cloud infrastructure, and ZeroTier-based connectivity for firewall bypass.

## Project Vision

**What**: On-demand VPN service that spins up when needed, tears down when idle
**Why**: Cost-effective, firewall-resistant VPN access with native macOS UX
**How**: Menu bar app + AWS EC2 + ZeroTier networking

### Components
1. **macOS Menu Bar App** - Native UI for VPN control
2. **AWS Instance Management** - Dynamic EC2 lifecycle (cost optimization)
3. **ZeroTier VPN** - Peer-to-peer networking with firewall bypass
4. **Orchestration** - Connects the pieces seamlessly

## Quick Start

*Project is in initialization phase. Commands will be added as development progresses.*

## Development

### Environment
- Platform: macOS (primary target)
- Cloud: AWS (EC2 for VPN servers)
- VPN: ZeroTier (network layer)
- AI: Claude Code (with extended permissions)

### Permissions
Claude Code is configured with:
- Web fetch: ZeroTier documentation
- SSH access: Local network infrastructure
- Web search: Research and troubleshooting

### Security Notes
- Credentials must never be committed (see `.gitignore`)
- AWS credentials via environment or AWS CLI config
- ZeroTier API tokens via keychain
- **TODO**: Migrate SSH password from settings.local.json to keychain

## Architecture

*To be defined as implementation progresses*

### Planned Tech Stack
TBD - Options under consideration:
- **macOS App**: Swift/SwiftUI or Objective-C
- **Backend**: Go, Rust, or Node.js for orchestration
- **AWS SDK**: Language-specific AWS SDK
- **ZeroTier**: API integration via HTTP

## Alpha-Wave Index
> Last indexed: 2026-02-21T21:23:00Z
> Files: 3

@alpha-wave/INDEX.md
@alpha-wave/TOPICS.md

Quick summaries available in `alpha-wave/summaries/`

## Brain-Wave Memory System

This project uses the three-agent Brain-Wave memory system:

### For Development (You)
- **New session**: Check `@alpha-wave/INDEX.md` for file overview
- **Working on feature**: Check `@alpha-wave/TOPICS.md` for related files
- **Deep dive**: Read file summaries in `alpha-wave/summaries/`

### For Maintenance (Agents)
- **Alpha-Wave**: `use alpha-wave agent` to refresh file index
- **Beta-Wave**: `use beta-wave agent` to create deep maps (run after Alpha-Wave)
- **REM**: `use rem agent` to sync and track changes

### Context Restoration
Full documentation: `.claude/rules/alpha-wave-context.md` (auto-loaded)

## Repository

- Remote: Private Gitea instance (192.168.1.83:3000)
- Branch: main
- Status: Initialization complete, awaiting first code

## Integration Points

### ZeroTier
- Docs: https://docs.zerotier.com
- Purpose: VPN network creation and management
- Access: API via HTTP

### AWS
- Service: EC2 for VPN server instances
- Purpose: On-demand compute for VPN endpoints
- Regions: TBD (likely multi-region for redundancy)

### Local Network
- Router: 192.168.1.1 (SSH access configured)
- Purpose: Network monitoring and configuration

## Next Steps

1. **Architecture Decision**
   - Choose implementation language(s)
   - Define component boundaries
   - Design API contracts

2. **Project Structure**
   - Create source directories
   - Add dependency management
   - Setup build system

3. **Menu Bar App Skeleton**
   - Basic macOS app template
   - Menu bar integration
   - Preference storage

4. **AWS Integration**
   - EC2 instance templates
   - Lifecycle management logic
   - Cost tracking

5. **ZeroTier Integration**
   - API client implementation
   - Network creation/deletion
   - Member authorization

## Notes

- Currently just configuration files
- No dependencies defined yet
- Architecture decisions pending
- Ready for rapid prototyping

---
*Initialized: 2026-02-21*
*Status: Pre-development*

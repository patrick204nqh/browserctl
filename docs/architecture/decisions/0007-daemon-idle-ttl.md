# ADR-0007: 30-Minute Idle TTL for Daemon Auto-Shutdown

**Date**: 2026-04-20
**Status**: accepted
**Deciders**: Patrick

## Context

The daemon runs as a background process holding a Chrome browser open. If a user forgets to shut it down manually, it will consume memory and CPU indefinitely. A self-termination policy is needed that balances session persistence (the core value of the tool) against resource hygiene.

## Decision

The daemon shuts itself down after 30 minutes of inactivity. Activity is defined as any JSON-RPC command received by the daemon. The `IdleWatcher` runs as a background thread, checks elapsed time since last command, and triggers a graceful shutdown if the threshold is exceeded.

## Alternatives Considered

### No auto-shutdown (manual only)
- **Pros**: Session never interrupted unexpectedly; user is fully in control
- **Cons**: Leaked browser processes are common — developers forget; Chrome is memory-heavy; multiple leaked daemons stack up
- **Why not**: The operational cost of leaked daemons outweighs the benefit of infinite persistence for typical developer workflows

### System-level idle detection (CPU/memory below threshold)
- **Pros**: Smarter — shuts down only when truly idle
- **Cons**: Complex to implement cross-platform; a page loading in the background could still appear idle by CPU metrics
- **Why not**: Command-based activity tracking is simpler, predictable, and sufficient

### Configurable TTL via flag
- **Pros**: Users with long-running workflows can extend the window
- **Cons**: Adds CLI surface area; 30 minutes covers the vast majority of interactive sessions
- **Why not**: YAGNI — can be added in v0.3 if real demand emerges

## Consequences

### Positive
- Chrome process is guaranteed to be reaped eventually without user action
- IdleWatcher is a single background thread with no external dependencies
- Shutdown is graceful — browser closes cleanly, socket file is removed, PID file is cleaned up

### Negative
- Long-running workflows (> 30 min of no commands) will be interrupted — the workflow must re-open the daemon
- The TTL is not persisted across daemon restarts — the timer always resets on launch

### Risks
- A workflow that sleeps for > 30 minutes between commands will lose its session — mitigation is to issue a `ping` as a keepalive if needed

# ADR-0001: Unix Domain Sockets for IPC

**Date**: 2026-04-20
**Status**: accepted
**Deciders**: Patrick

## Context

The daemon (`browserd`) needs to accept commands from the `browserctl` CLI and from workflow scripts running in separate processes. A communication channel is required that is fast, reliable, and secure for local-only use. The tool is explicitly not designed for remote access.

## Decision

We use a Unix domain socket at `~/.browserctl/browserd.sock` with file permissions set to `0o600` as the sole IPC channel between the CLI/workflows and the daemon.

## Alternatives Considered

### TCP Loopback (localhost:PORT)
- **Pros**: Universally supported, easy to test with curl
- **Cons**: Exposed to any process on the machine; requires port allocation and conflict management
- **Why not**: Security footprint is larger than necessary for a local-only tool; no benefit over Unix sockets locally

### Named Pipes (FIFO)
- **Pros**: Simple, Unix-native
- **Cons**: Half-duplex by default; managing bidirectional communication requires two FIFOs; no connection semantics
- **Why not**: JSON-RPC needs request/response pairs; FIFOs make this unnecessarily complex

## Consequences

### Positive
- File permissions (`0o600`) restrict access to the owning user — no firewall rules needed
- Lower latency than TCP loopback (no TCP stack overhead)
- Socket path is a stable, discoverable contract (`~/.browserctl/browserd.sock`)

### Negative
- Not accessible from remote machines by design — intentional constraint
- Requires the daemon to clean up the socket file on shutdown (handled in `Server#run`)

### Risks
- Stale socket file if daemon crashes without cleanup — mitigated by PID file check on startup

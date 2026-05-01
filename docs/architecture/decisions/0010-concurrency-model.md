# ADR-0010: Thread-Per-Client with Layered Mutexes

**Date**: 2026-05-01
**Status**: accepted
**Deciders**: Patrick

## Context

The daemon accepts commands from multiple concurrent clients (CLI invocations, workflow scripts) over a Unix socket. Browser operations are slow and blocking. A concurrency model is needed that allows concurrent clients without corrupting shared state — specifically the page registry and individual page sessions — while remaining simple enough to reason about without async frameworks.

## Decision

The server spawns one Ruby thread per connected client. Shared state is protected by two layers of mutexes: a global mutex (`@global_mutex`) that guards the page registry and last-used timestamp, and a per-page mutex (`PageSession#mutex`) with a `ConditionVariable` for pause/resume that serializes operations on each individual page. A separate KV store mutex protects the daemon-scoped key-value store. The idle watcher runs as a fourth background thread. Lock ordering is always global first, then per-page.

## Alternatives Considered

### Single-threaded event loop (e.g., EventMachine / async)
- **Pros**: No mutex complexity; no deadlock risk; lower memory per connection
- **Cons**: Ferrum uses blocking I/O to CDP; adapting it to an async event loop requires wrapping every CDP call; adds a significant non-trivial dependency
- **Why not**: The browser control layer is inherently blocking; an event loop buys nothing without async-capable Ferrum bindings

### Thread pool with fixed worker count
- **Pros**: Bounded resource usage; prevents thread explosion under load
- **Cons**: Clients block waiting for a pool slot; for a local developer tool, concurrent client count is rarely > 2-3
- **Why not**: The overhead of pool management is not justified; the tool is not designed for high-concurrency workloads

### Global lock (single mutex around all operations)
- **Pros**: Trivially correct; no deadlock risk
- **Cons**: Serializes all commands across all clients and all pages; kills concurrency for independent page operations
- **Why not**: Two clients operating on different pages should not block each other

## Consequences

### Positive
- Independent pages can be operated concurrently — the per-page mutex only blocks operations on the same page
- Global mutex is held only during fast registry lookups, not during browser I/O — contention is minimal
- Lock ordering (global → per-page) is consistent throughout the codebase, eliminating deadlock risk
- `ConditionVariable` on per-page mutex enables pause/resume semantics for workflow step coordination

### Negative
- No thread pool upper bound — a burst of concurrent clients spawns an unbounded number of threads
- Ferrum's browser instance is shared across all threads without internal thread-safety guarantees; correctness relies on per-page mutex ensuring only one thread operates on a given page at a time
- Thread lifecycle is managed by GC, not explicitly — leaked threads from abruptly-closed connections are not explicitly cleaned up

### Risks
- A deadlock is possible if a handler acquires the global mutex and then tries to acquire a per-page mutex while another thread holds the per-page mutex and waits for the global mutex — current code avoids this but the constraint is not enforced mechanically

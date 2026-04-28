# ADR-0003: Named Page Handles as Core Abstraction

**Date**: 2026-04-20
**Status**: accepted
**Deciders**: Patrick

## Context

Browser automation libraries typically expose page objects tied to a specific tab or window. When using a persistent daemon across multiple CLI invocations, the caller needs a way to reference a specific tab without holding a live Ruby object between calls. A naming scheme is needed that survives across process boundaries.

## Decision

Pages are identified by a caller-provided string name (e.g., `login`, `dashboard`). The daemon maintains a registry (`@pages` hash protected by a Mutex) mapping names to Ferrum page objects. All commands that operate on a page accept a page name rather than an opaque handle.

## Alternatives Considered

### Numeric IDs assigned by the daemon
- **Pros**: Simple to implement; no name collision risk
- **Cons**: Callers must track IDs externally; meaningless in scripts; hard to read in CLI history
- **Why not**: Named pages make workflows self-documenting (`page(:login)` vs `page(3)`)

### Single implicit page (no naming)
- **Pros**: Simplest API — no page concept at all
- **Cons**: Cannot open multiple tabs; limits multi-step workflows that need parallel pages
- **Why not**: Multi-page workflows (e.g., open a login page and a dashboard simultaneously) are a primary use case

## Consequences

### Positive
- Workflow scripts are self-documenting — `page(:login).navigate(url)` reads clearly
- Named pages survive across CLI invocations — the name is the stable reference
- `page list` command gives a human-readable view of what's open

### Negative
- Name collision is the caller's responsibility — opening `login` twice replaces the first
- Page name is a string key, not a validated identifier — typos silently open new pages

### Risks
- Page registry grows unbounded if callers never call `close_page` — mitigated by the 30-minute idle shutdown (ADR-0007)

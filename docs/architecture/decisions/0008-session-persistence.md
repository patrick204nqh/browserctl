# ADR-0008: Snapshot-Based Session Persistence

**Date**: 2026-05-01
**Status**: accepted
**Deciders**: Patrick

## Context

The daemon holds live browser state (open pages, cookies, localStorage) that is lost when the process exits. Users need a way to save and restore sessions across daemon restarts for workflows that span multiple work sessions. The persistence format must be human-inspectable, secure by default, and not require a running browser to read.

## Decision

Sessions are saved as a set of JSON files under `~/.browserctl/sessions/<name>/`: `metadata.json`, `cookies.json`, `local_storage.json`, and optionally `session_storage.json`. All files are written with `0o600` permissions. An optional AES-256-GCM encryption mode is available, with keys stored in the macOS Keychain. Sessions are not automatically restored on daemon restart — they must be explicitly loaded via `session_load`.

## Alternatives Considered

### Marshal / Ruby object serialization
- **Pros**: Captures the full Ruby object graph with no manual field selection
- **Cons**: Format is Ruby-version-sensitive and opaque; cannot be inspected without a running Ruby process; security implications of deserializing untrusted data
- **Why not**: Sessions may need to be inspected or ported; Marshal is a poor fit for long-lived storage

### SQLite database
- **Pros**: Queryable; atomic writes; handles concurrent access safely
- **Cons**: Adds a native dependency; overkill for a single-user local tool; sessions are not frequently queried
- **Why not**: File-per-session JSON is simpler and directly inspectable with standard tools

### Auto-restore on daemon restart
- **Pros**: Seamless recovery after crashes
- **Cons**: Requires serializing page object references and Ferrum state, which is not safely serializable; a partially-restored browser is worse than a clean start
- **Why not**: Explicit `session_load` keeps the contract clear; implicit restoration hides failures

## Consequences

### Positive
- Sessions are inspectable with any JSON tool — no special tooling required
- `0o600` permissions restrict access to the owning user without encryption
- Optional AES-256-GCM with macOS Keychain provides strong protection for sensitive cookies without per-command password prompts
- Session files can be version-controlled or shared (when encryption is used)

### Negative
- sessionStorage is collected but not restored — it is tab-scoped and cannot survive page navigation
- Session load is not atomic: if restoring page 2 fails after page 1 succeeds, the browser is left in a partial state
- macOS Keychain integration is Darwin-only; Linux/CI users rely solely on file permissions

### Risks
- Stale session files accumulate in `~/.browserctl/sessions/` with no automatic pruning — users must clean up manually

# ADR-0009: Uniform JSON-RPC Error Format with Per-Thread Isolation

**Date**: 2026-05-01
**Status**: accepted
**Deciders**: Patrick

## Context

The daemon handles commands from multiple concurrent clients over a Unix socket. Errors can occur at several layers: input validation, page operation failures, browser exceptions, and unknown commands. A consistent error shape is needed so clients can handle all failure cases uniformly without special-casing each command.

## Decision

All responses use one of two shapes: `{ ok: true, ...fields }` for success or `{ error: "message string" }` for failure, with an optional `code` field (e.g., `page_not_found`, `domain_not_allowed`) for machine-readable error discrimination. Per-client threads catch all `StandardError` exceptions and serialize them into the error shape. Errors are isolated per client connection — a failing command on one client does not affect others.

## Alternatives Considered

### JSON-RPC 2.0 error objects (`{ error: { code: N, message: "..." } }`)
- **Pros**: Spec-compliant; numeric codes are unambiguous; many client libraries understand it natively
- **Cons**: Numeric codes require a lookup table; the spec's predefined codes (`-32600` etc.) don't map naturally to browser automation errors
- **Why not**: The spec's error envelope adds nesting without benefit for a single-client, single-server local tool

### Exception classes propagated to the client
- **Pros**: Rich type information; clients can pattern-match on exception class
- **Cons**: Requires a serialization convention for exception types; couples client and server class hierarchies
- **Why not**: The Unix socket boundary already breaks object identity; string messages are sufficient for the CLI use case

### Structured error codes on every response
- **Pros**: Clients can branch on error type without string-matching
- **Cons**: Significant cataloguing overhead; most errors are terminal (surface to user as message)
- **Why not**: Only errors that clients need to handle programmatically (e.g., `page_not_found` to trigger page creation) warrant codes; the rest are human-readable messages

## Consequences

### Positive
- Clients need only check `response.key?(:error)` — one branch, all commands
- Per-thread exception isolation prevents one client's failure from cascading to others
- Error messages include the Ruby exception class in daemon logs for debugging while exposing only the message to clients

### Negative
- Multi-step operations (e.g., `session_load` restoring multiple pages) have no transactional guarantee — partial success is possible with no rollback
- Machine-readable `code` values are only defined for a subset of errors; most handler errors are string-only, limiting programmatic discrimination
- No structured error codes for input validation failures — clients cannot distinguish "wrong param type" from "page operation failed" without string inspection

### Risks
- The 60-second client-side response timeout is hardcoded — long-running commands (large page loads, full-page screenshots) may time out on slow machines

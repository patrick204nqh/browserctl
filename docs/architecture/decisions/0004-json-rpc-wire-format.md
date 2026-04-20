# ADR-0004: JSON-RPC as Wire Protocol

**Date**: 2026-04-20
**Status**: accepted
**Deciders**: Patrick

## Context

The daemon and CLI communicate over a Unix socket. A framing and serialization format is needed for requests and responses. The format should be simple to implement, human-readable for debugging, and language-agnostic to support future clients.

## Decision

We use a subset of JSON-RPC 2.0 as the wire format: newline-delimited JSON objects with a `method` field and a `params` hash for requests, and an `ok` boolean plus result fields or an `error` string for responses.

## Alternatives Considered

### Raw line-delimited strings
- **Pros**: Dead simple
- **Cons**: No structured params, no structured errors; any evolution requires a new framing convention
- **Why not**: Too brittle for a tool with many command types and complex params

### MessagePack / CBOR (binary)
- **Pros**: More compact, faster to parse
- **Cons**: Not human-readable; harder to debug with basic tools (`nc`, `jq`)
- **Why not**: Compactness is not a bottleneck for local IPC; debuggability matters more

### gRPC / Protocol Buffers
- **Pros**: Typed schema, codegen, streaming support
- **Cons**: Heavy dependency; requires schema files and codegen toolchain; significant setup overhead
- **Why not**: Over-engineered for a single-machine daemon talking to a co-located CLI

## Consequences

### Positive
- Protocol is inspectable with standard tools: `echo '{"method":"ping","params":{}}' | nc -U ~/.browserctl/browserd.sock`
- Language-agnostic — any client that can write JSON to a socket can talk to the daemon
- Simple to extend — new commands are new method names, no schema changes

### Negative
- No formal schema enforcement — invalid params produce runtime errors, not compile-time errors
- No streaming — large snapshots are returned as a single JSON blob

### Risks
- Large HTML snapshots could produce very large JSON responses — mitigated by the SnapshotBuilder's element filtering and 80-char text truncation (ADR-0006)

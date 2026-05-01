# ADR-0011: PNG Default for Screenshots with Path-Scoped Safety

**Date**: 2026-05-01
**Status**: accepted
**Deciders**: Patrick

## Context

The `screenshot` command captures the browser viewport as an image file. A default format and allowed format set must be chosen. Screenshot paths are user-supplied, which creates a path traversal risk — the daemon must validate paths without being overly restrictive for legitimate use. Screenshots and DOM snapshots (ADR-0006) serve different purposes and are distinct commands.

## Decision

Screenshots default to PNG. JPG and JPEG are also accepted (case-insensitive extension check). Paths are validated against two allowed roots: `~/.browserctl/screenshots/` and the caller's current working directory. Symlinks are resolved before validation. Full-page capture is available via a `--full` flag; viewport capture is the default. Screenshots and DOM snapshots are separate commands — `snapshot` returns JSON element data, `screenshot` returns an image file.

## Alternatives Considered

### WebP as default format
- **Pros**: Better compression than PNG at equivalent quality; modern browser support
- **Cons**: Less universally supported by image viewers and tools; Ferrum delegates format to Chrome, and WebP support in headless Chrome screenshot APIs is less consistent
- **Why not**: PNG is universally supported and lossless; compression savings are not a priority for a developer debugging tool

### Allow any path (no restriction)
- **Pros**: Maximum flexibility for callers
- **Cons**: The daemon runs with the user's file permissions and could overwrite arbitrary files if given a malicious path; CI environments may have write access to sensitive paths
- **Why not**: Path traversal attacks are a known risk for any tool that writes user-supplied paths; scoping to two well-known roots is a minimal, non-intrusive safety measure

### Embed screenshots in JSON-RPC response (base64)
- **Pros**: No filesystem writes required; response is self-contained
- **Cons**: Large base64 blobs in JSON responses conflict with the streaming limitation noted in ADR-0004; base64 adds ~33% overhead; callers typically want a file anyway
- **Why not**: File-based output is the natural interface for screenshot use cases (sharing, attaching to tickets, visual diffing)

## Consequences

### Positive
- PNG losslessness preserves text legibility for debugging UI state — preferred over lossy formats for developer tooling
- Path restriction to two roots prevents accidental or malicious overwrites without requiring a separate permission system
- `--full` flag enables full-page capture when the visible viewport is insufficient (e.g., long forms)
- Screenshots and snapshots are complementary: snapshots for agent action planning, screenshots for human review and debugging

### Negative
- JPG quality is browser-default with no user-controllable quality parameter — fine for most use cases but not suitable for image-quality-sensitive workflows
- Viewport resolution depends on the Chrome instance's configured viewport — no explicit resolution control exposed to callers
- Screenshots cannot be returned inline in CLI output; callers must handle the output file path

### Risks
- Path validation resolves symlinks at write time — a symlink created after validation but before write (TOCTOU) could redirect the write; acceptable risk for a single-user local tool

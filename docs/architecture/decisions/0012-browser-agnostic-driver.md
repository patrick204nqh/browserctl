# ADR-0012: Browser-Agnostic Driver Layer

**Date**: 2026-05-02
**Status**: superseded (2026-05-10) — deferred until a second driver exists
**Extends**: ADR-0002 (Ferrum/CDP remains the implementation; this ADR adds the abstraction layer in front of it)
**Deciders**: Patrick

## Superseded note (v0.13)

The `Browserctl::Driver::Base` abstraction defined here was deleted in v0.13
(see `docs/plans/v0.13-lean.md` PR 1). Inspection at the v0.13 cut showed
`Driver::Base` was a 13-line stub with `Driver::CDP` as the only subclass and
no handler code interacting with the abstract interface. Brave/Chromium
support already lives inside `Driver::CDP` via the `browser:` constructor
parameter — the abstraction earned zero rent.

`Browserctl::Driver::CDP` remains and keeps the `Driver` namespace as the
extension point. If/when a second protocol driver (e.g. WebDriver for Firefox
or Safari) is actually being built, revisit this ADR and re-introduce a base
class shaped by the real second implementation rather than a speculative one.

The rest of this document is preserved for historical context.

---


## Context

Today every handler calls Ferrum APIs directly. No boundary exists between "what the daemon does" and "how Chrome does it". Adding any non-Chrome browser means rewriting all handler files.

Brave support was the immediate trigger: Brave is CDP-compatible and widely used for privacy-conscious browsing, making it a natural fit for browser automation workflows. But the deeper motivation is that the zero-abstraction design made every future browser addition a full codebase rewrite.

## Decision

Introduce `Browserctl::Driver::Base` with `Driver::CDP` as the concrete implementation. Handlers interact with the driver interface; the driver owns the browser library dependency (Ferrum).

### Driver model

One driver per protocol (CDP, WebDriver), not per browser. `Driver::CDP` serves Chrome, Chromium, and Brave — all three are CDP-compatible. A future `Driver::WebDriver` would serve Firefox and Safari via W3C WebDriver.

### Capability flags

Protocol-specific features (e.g. the DevTools inspector URL) are gated behind `driver.supports?(:devtools)` rather than being conditionally implemented per-driver. Unsupported capabilities return `{ error: "..." }` — consistent with the uniform error shape established in ADR-0009.

### What is NOT abstracted

The Unix socket server, `CommandDispatcher` routing, session serialisation, `IdleWatcher`, `Detectors`, and `SnapshotBuilder` are all protocol-agnostic today and remain unchanged.

### Brave binary resolution

`Driver::CDP` resolves the Brave binary from well-known install paths per platform (macOS, Linux, Windows), with an override via the `BRAVE_PATH` environment variable. Chromium resolution follows the same pattern via `CHROMIUM_PATH`. Chrome continues to be found automatically by Ferrum.

## Alternatives Considered

### Keep Ferrum calls in handlers, use `responds_to?` guards
- **Pros**: Minimal code change
- **Cons**: Every new browser capability requires touching every handler; no clear extension point; hard to test without a real browser
- **Why not**: Does not solve the structural problem

### One driver class per browser (ChromeDriver, BraveDriver, ChromiumDriver)
- **Pros**: Maximum isolation per browser
- **Cons**: Massive duplication — Brave and Chromium are identical to Chrome at the CDP level; only the binary path differs
- **Why not**: CDP compatibility means the protocol is shared; differentiating by browser binary is sufficient

## Consequences

### Positive
- Adding a new browser = add (or configure) a driver subclass; handler files are untouched
- `Driver::CDP` serves Chrome, Chromium, and Brave from a single implementation
- The `devtools` command now checks capability before building its URL, making it safe to call on any driver
- Handlers and tests can use driver doubles without a real browser process
- Ferrum is an implementation detail of `Driver::CDP`, not a framework-level dependency

### Negative
- One additional abstraction layer to understand
- `Driver::CDP` initialises Ferrum in its constructor — tests that call `Driver::CDP.new` directly need a browser binary available

### Risks
- CDP is a Chrome-internal protocol — breaking changes across Chrome versions remain a risk, mitigated by Ferrum's version tracking (unchanged from ADR-0002)

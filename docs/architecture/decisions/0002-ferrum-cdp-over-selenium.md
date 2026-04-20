# ADR-0002: Ferrum/CDP over Selenium/WebDriver

**Date**: 2026-04-20
**Status**: accepted
**Deciders**: Patrick

## Context

The daemon needs to control a real browser. Two established approaches exist: Selenium/WebDriver (W3C standard, multi-browser) and Chrome DevTools Protocol (CDP, Chrome-specific but modern). The tool targets developer and AI agent workflows, not cross-browser CI testing.

## Decision

We use [Ferrum](https://github.com/rubycdp/ferrum) as the browser control library. Ferrum is a Ruby CDP client that communicates directly with Chrome over CDP without the WebDriver intermediary layer.

## Alternatives Considered

### Selenium + ChromeDriver
- **Pros**: W3C standard, multi-browser, large ecosystem, well-documented
- **Cons**: Requires a separate ChromeDriver process matching the browser version; adds latency through the WebDriver bridge; slower for interactive/persistent use
- **Why not**: The WebDriver architecture is designed for stateless test runs, not persistent sessions. Version matching of browser and driver is an ongoing maintenance burden.

### Playwright (Ruby bindings)
- **Pros**: Modern, multi-browser, excellent async support
- **Cons**: Ruby bindings are thin wrappers over the Node.js process; adds a Node.js runtime dependency; not designed for persistent daemon use
- **Why not**: Introducing a Node.js subprocess dependency for a Ruby tool adds unnecessary operational complexity.

## Consequences

### Positive
- Direct CDP communication — no WebDriver intermediary, lower latency
- No ChromeDriver version pinning required
- Full access to CDP features (evaluate JS, intercept requests, etc.) without abstraction leakage
- Ferrum is pure Ruby — no native extensions, no secondary runtimes

### Negative
- Chrome/Chromium only — cross-browser support is not possible without replacing Ferrum
- Less community documentation than Selenium

### Risks
- CDP is a Chrome internal protocol — breaking changes are possible across Chrome versions, mitigated by tracking Ferrum releases

# Architecture Documentation

## Diagrams

C4 model diagrams showing the system at increasing levels of detail.

| Diagram | Description |
|---------|-------------|
| [C4 Context](diagrams/c4-context.md) | System in its environment — users, Chrome, filesystem |
| [C4 Container](diagrams/c4-container.md) | Runtime pieces — daemon, CLI, socket, workflows |
| [C4 Component](diagrams/c4-component.md) | Daemon internals — dispatcher, watcher, snapshot builder |

## Architecture Decision Records

Key decisions that shaped the system, with context and trade-offs.

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [0001](decisions/0001-unix-domain-sockets.md) | Unix Domain Sockets for IPC | accepted | 2026-04-20 |
| [0002](decisions/0002-ferrum-cdp-over-selenium.md) | Ferrum/CDP over Selenium/WebDriver | accepted | 2026-04-20 |
| [0003](decisions/0003-named-page-handles.md) | Named Page Handles as core abstraction | accepted | 2026-04-20 |
| [0004](decisions/0004-json-rpc-wire-format.md) | JSON-RPC as wire protocol | accepted | 2026-04-20 |
| [0005](decisions/0005-ruby-dsl-for-workflows.md) | Ruby DSL for workflow authoring | accepted | 2026-04-20 |
| [0006](decisions/0006-ai-optimized-snapshot-format.md) | AI-optimized DOM snapshot format | accepted | 2026-04-20 |
| [0007](decisions/0007-daemon-idle-ttl.md) | 30-minute idle TTL for auto-shutdown | accepted | 2026-04-20 |

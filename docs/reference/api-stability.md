# browserctl API Stability

browserctl's public surface is split into three stability zones. Every command, method, and field belongs to exactly one zone.

---

## The three zones

### Fixed — Protocol layer
**The wire protocol: JSON-RPC command names, response field names, socket path convention.**

Locked after v0.6. Never changes without a major version bump and an explicit migration path. External tools (non-Ruby clients, other language bindings) depend on this layer.

What is Fixed:
- Command names in `COMMAND_MAP` (the strings sent over the Unix socket)
- Response shapes: every required and optional field per command (documented below)
- Socket path convention: `~/.browserctl/<name>.sock`
- The JSON-RPC envelope: `{ cmd:, name:?, ...params }` → `{ ok: true, ...data }` or `{ error: "..." }`

### Stable — Interface layer
**CLI command names and flags. `Browserctl::Client` method signatures. `PageProxy` public methods.**

Changes require a deprecation notice in one minor release before removal. Old forms are kept as aliases for one release cycle.

What is Stable:
- CLI command names and their option flags
- `Browserctl::Client` public method names and keyword arguments
- `PageProxy` public methods (the workflow DSL page object)

The Stable surface is locked by `spec/fixtures/public_surface.yml` and enforced by `spec/public_surface_spec.rb`. Drift (any added, removed, or renamed public symbol on `Browserctl::Client`, `Browserctl::PageProxy`, or the `bin/browserctl` top-level command dispatch table) fails CI. Any PR that intentionally changes the Stable surface must update `spec/fixtures/public_surface.yml` in the same commit; `public_surface_spec` enforces parity.

### Extension — Plugin & Workflow layer
**The plugin registration API, workflow DSL, and internal Ruby APIs.**

Can change between minor versions with a changelog entry. No deprecation window required.

What is Extension:
- `Browserctl.workflow { }` DSL syntax
- `Browserctl.register_command` plugin API
- `Browserctl.lookup_workflow`, `Browserctl.registry_snapshot` accessors
- `Browserctl.lookup_plugin_command`, `Browserctl.plugin_commands_snapshot` accessors
- `WorkflowContext` and `WorkflowDefinition` internals
- `Browserctl::Runner` public methods
- `Browserctl::Recording`
- `Browserctl::Tracing` (pluggable tracing backend; default no-op — see `lib/browserctl/tracing.rb` for the `Backend` contract)
- `Browserctl.socket_path`, `Browserctl.pid_path`, `Browserctl.log_path`
- `store` / `fetch` daemon KV wire commands (see "Daemon KV (`store` / `fetch`)" below)

---

## Fixed zone — command reference

Every command that flows over the wire. Name, required params, optional params, and response fields are all Fixed once v0.6 ships.

The canonical machine-readable contract for Fixed-zone response shapes is `spec/fixtures/public_surface.yml` under the `fixed_zone:` key. `spec/public_surface_spec.rb` invokes every handler in `COMMAND_MAP` and fails CI if a response gains an undeclared field or loses a required one. The tables below stay human-readable; the lock-file is the source of truth.

### Page lifecycle

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `page_open` | `name` | `url` | `ok`, `name` |
| `page_close` | `name` | — | `ok` |
| `page_list` | — | — | `pages` (array of strings) |
| `page_focus` | `name` | — | `ok` |

### Navigation & interaction

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `navigate` | `name`, `url` | — | `ok`, `url`, `challenge` |
| `fill` | `name`, `value` | `selector`, `ref` | `ok` |
| `click` | `name` | `selector`, `ref` | `ok` |
| `evaluate` | `name`, `expression` | — | `ok`, `result` |
| `url` | `name` | — | `ok`, `url` |
| `wait` | `name`, `selector` | `timeout` (default 30s) | `ok`, `selector` |

One of `selector` or `ref` is required for `fill` and `click`. Both cannot be omitted.

### Observation

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `snapshot` | `name` | `format` (`"elements"`\|`"html"`), `diff` | `ok`, `snapshot` or `html`, `challenge`, `nonce` |
| `screenshot` | `name` | `path`, `full` | `ok`, `path` |

`snapshot` with `format: "elements"` (default) returns `snapshot` field — a JSON array of interactable elements with ref IDs. With `format: "html"` returns `html` field. Both include `challenge` and `nonce`.

`nonce` is a server-generated hex string (16 chars) unique per response. It is present in every `snapshot` response regardless of `format`. Consumers can use it to delimit page-provided content — the page cannot forge or predict the value.

### HITL (Human-in-the-loop)

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `pause` | `name` | `message` | `ok`, `paused: true`, `message` |
| `resume` | `name` | — | `ok`, `paused: false` |

### Data (v0.15+, unified — Fixed)

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `data_get` | `name`, `key`, `scope` | — | `ok`, `scope`, `key`, `value` |
| `data_set` | `name`, `key`, `value`, `scope` | `domain` (cookies only), `path` | `ok`, `scope`, `key` |
| `data_delete` | `name`, `scope` | — | `ok`, `scope`, `deleted` |
| `data_list` | `name`, `scope` | — | `ok`, `scope`, `entries`, `count` |

`scope` must be one of `cookies`, `localStorage`, `sessionStorage`. Invalid
scope returns a typed `INVALID_ARGUMENT` error. Introduced by ADR-0021 as
the consolidation of the legacy `cookie *` and `storage *` families.

### Cookies / Storage (removed in v0.16)

The `cookie *` / `storage *` wire commands, the matching CLI verbs, and the
matching `Browserctl::Client` methods shipped in v0.15 as aliases over the
`data` verb family. They were removed in v0.16 — see ADR-0021. Use
`data_get` / `data_set` / `data_delete` / `data_list` with a `scope:` of
`cookies`, `localStorage`, or `sessionStorage`.

### DevTools

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `devtools` | `name` | — | `ok`, `devtools_url` |

### Daemon control

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `ping` | — | — | `ok`, `pid`, `protocol_version` |
| `shutdown` | — | — | `ok` |

---

## Stable zone — CLI reference

CLI command names and their flags map 1-to-1 to wire commands via the subcommand routers in `lib/browserctl/commands/`. There are no abbreviation aliases — CLI names match their wire counterparts exactly.

CLI process exit codes are also part of this zone — see [exit-codes.md](exit-codes.md) for the full table. Error `code` strings (the machine-readable contract on stderr and on the wire) are also Stable — see [errors.md](errors.md) for the full reference.

---

## Extension zone — internal surfaces

### Daemon KV (`store` / `fetch`)

The `store` and `fetch` wire commands provide a small in-memory key/value scratchpad on the daemon. They are **Extension**, not Fixed — shape and semantics may change between minor releases with a changelog entry.

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `store` | `key`, `value` | — | `ok` |
| `fetch` | `key` | — | `ok`, `value` |

`fetch` returns `{ error: "key '<key>' not found", code: "key_not_found" }` when the key has never been stored.

Known limits, intentional at this stage:

- **No TTL.** Entries live until the daemon stops or is explicitly overwritten.
- **No scoping.** Keys share a single flat namespace across every page, session, and workflow on the daemon. There is no per-page, per-session, or per-workflow isolation.
- **Per-daemon, not per-session, lifetime.** Values persist across `workflow run` invocations for as long as the daemon is running, and are lost when the daemon stops. Saving or loading a session does not save or restore KV state.

These limits are why `store`/`fetch` are Extension. A future revision may add scoping, TTLs, or session-bound lifetime, and Extension status leaves room to do that without a major bump.

### `Browserctl::Driver::PageDriver`

The `PageDriver` interface (`lib/browserctl/driver/page_driver.rb`) and its only shipped implementation `FerrumPageDriver` are **Extension**. They exist so handlers can be unit-tested without spawning Chrome — see `spec/support/fake_page_driver.rb` and `spec/unit/handlers/` for the test double and unit specs.

The interface is **not** a plugin point. Per the v0.15 plan, shipping a non-Ferrum backend is explicitly a non-goal of the 1.0 line; the seam exists for testability. Method signatures may change between minor releases with a changelog entry.

---

## Removed in v0.16

The following Fixed-zone surfaces shipped in v0.15 as deprecation-window
aliases over the unified `data` verb family and were removed in v0.16. See
ADR-0021 (`docs/architecture/decisions/0021-data-verb-consolidation.md`)
for the design.

| Surface (removed) | Replacement | Notes |
|---|---|---|
| Wire: `cookies` | `data_list` with `scope: "cookies"` | Returns full cookie array; same per-cookie shape. |
| Wire: `set_cookie` | `data_set` with `scope: "cookies"` | `domain:` still required. |
| Wire: `delete_cookies` | `data_delete` with `scope: "cookies"` | Returns `deleted:` count. |
| Wire: `import_cookies` | `data_set` per cookie with `scope: "cookies"` | Or land a `data_import` follow-up. |
| Wire: `storage_get` | `data_get` with `scope: "localStorage"` / `"sessionStorage"` | Long scope names canonical. |
| Wire: `storage_set` | `data_set` with `scope: "localStorage"` / `"sessionStorage"` | |
| Wire: `storage_delete` | `data_delete` with `scope: "localStorage"` / `"sessionStorage"` | |
| Wire: `storage_export` / `storage_import` | `data_list` + client-side file I/O | `data export` / `data import` may land pre-1.0. |
| Client: `Client#cookies`, `#set_cookie`, `#delete_cookies`, `#import_cookies`, `#export_cookies` | `Client#data_get`, `#data_set`, `#data_delete`, `#data_list` | Removed in v0.16. |
| Client: `Client#storage_get`, `#storage_set`, `#storage_export`, `#storage_import`, `#storage_delete` | same as above | |
| CLI: `cookie <op>` | `data <op> --scope cookies` | `cookie` CLI verb removed in v0.16. |
| CLI: `storage <op>` | `data <op> --scope localStorage\|sessionStorage` | `storage` CLI verb removed in v0.16. The `--store local\|session` short forms were v0.15-only wire aliases and were removed in v0.16. |

Removal timeline:

| Milestone | State of the surfaces |
|---|---|
| v0.14 | Sole API. |
| v0.15 | Aliases that delegate to `data`, emit a one-line deprecation warning, stay covered by integration tests. |
| v0.16 | Aliases and warning lines removed. Only `data` remains. |

---

## Breaking changes log

### v0.15 — Data verb consolidation

v0.15 introduces a unified `data` verb family that subsumes the legacy
`cookie *` and `storage *` commands. The old surfaces continue to ship in
v0.15 as aliases with a one-line deprecation warning (suppressed under
`--output json`); they were removed in v0.16. See the "Removed in v0.16"
section above for the full migration table, and ADR-0021 for the design.

| New verb | Replaces |
|---|---|
| `data_get` | `storage_get` |
| `data_set` | `set_cookie`, `storage_set` |
| `data_delete` | `delete_cookies`, `storage_delete` |
| `data_list` | `cookies`, `storage_export` (in-memory) |

The implementation commit carries `Release-As: 0.15.0` so release-please
does not interpret the `BREAKING CHANGE:` footer as a 1.0 bump — the 1.0
lock comes after the v0.15 soak.

### v0.13 — Session removal

The `session` CLI commands and the `session_*` JSON-RPC wire commands are removed. `state` is now the only persistence path. Users on v0.12 sessions must regenerate their state with `state save` before upgrading; there is no migrate command.

| Removed wire command | Replacement |
|---|---|
| `session_save` | `state_save` |
| `session_load` | `state_load` |
| `session_list` | `state_list` |
| `session_delete` | `state_delete` |

The workflow DSL methods `save_session`, `load_session`, and `list_sessions` are also removed; use `save_state` / `load_state` instead.

### v0.6 — Protocol version 2

v0.6 is a breaking release. `PROTOCOL_VERSION` was bumped from `"1"` to `"2"`. Clients must check `ping[:protocol_version]` and reject `"1"` daemons.

| Old wire command | New wire command | Change |
|---|---|---|
| `open_page` | `page_open` | noun-verb reorder |
| `close_page` | `page_close` | noun-verb reorder |
| `list_pages` | `page_list` | noun-verb reorder |
| `goto` | `navigate` | full English word |
| `wait_for` + `watch` | `wait` | unified (single timeout param) |
| `clear_cookies` | `delete_cookies` | `delete` prefix convention |
| `inspect` | `devtools` | descriptive name |
| — | `storage_get/set/export/import/delete` | new (localStorage/sessionStorage) |
| `pause` | `pause` (+ optional `message:` param) | backward-compatible addition |

### v0.5 — Protocol version 1

| Issue | Status |
|-------|--------|
| CLI cookie commands used underscores (`set_cookie`, `clear_cookies`) | ✅ Fixed — renamed to `set-cookie`, `clear-cookies` at the CLI layer |
| `ping` response lacked protocol version | ✅ Fixed — `protocol_version: "1"` added |

---

## Protocol versioning

The `ping` response includes `protocol_version` — currently `"2"` (shipped in v0.6). Clients can check this field before sending commands to verify compatibility:

```ruby
res = client.ping
raise "incompatible daemon" unless res[:protocol_version] == "2"
```

Future incompatible protocol changes will increment this number and document the migration path here.

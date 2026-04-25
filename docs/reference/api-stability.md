# browserctl API Stability

browserctl's public surface is split into three stability zones. Every command, method, and field belongs to exactly one zone.

---

## The three zones

### Fixed — Protocol layer
**The wire protocol: JSON-RPC command names, response field names, socket path convention.**

Locked after v0.5. Never changes without a major version bump and an explicit migration path. External tools (non-Ruby clients, other language bindings) depend on this layer.

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

### Extension — Plugin & Workflow layer
**The plugin registration API, workflow DSL, and internal Ruby APIs.**

Can change between minor versions with a changelog entry. No deprecation window required.

What is Extension:
- `Browserctl.workflow { }` DSL syntax
- `Browserctl.register_command` plugin API
- `REGISTRY`, `PLUGIN_COMMANDS` constants
- `WorkflowContext` and `WorkflowDefinition` internals
- `Browserctl::Runner` public methods
- `Browserctl::Recording`
- `Browserctl.socket_path`, `Browserctl.pid_path`, `Browserctl.log_path`

---

## Fixed zone — command reference

Every command that flows over the wire. Name, required params, optional params, and response fields are all Fixed once v0.5 ships.

### Page lifecycle

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `open_page` | `name` | `url` | `ok`, `name` |
| `close_page` | `name` | — | `ok` |
| `list_pages` | — | — | `pages` (array of strings) |

### Navigation & interaction

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `goto` | `name`, `url` | — | `ok`, `url`, `challenge` |
| `fill` | `name`, `value` | `selector`, `ref` | `ok` |
| `click` | `name` | `selector`, `ref` | `ok` |
| `evaluate` | `name`, `expression` | — | `ok`, `result` |
| `url` | `name` | — | `ok`, `url` |

One of `selector` or `ref` is required for `fill` and `click`. Both cannot be omitted.

### Observation

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `snapshot` | `name` | `format` (`"ai"`\|`"html"`), `diff` | `ok`, `snapshot` or `html`, `challenge`, `nonce` |
| `screenshot` | `name` | `path`, `full` | `ok`, `path` |
| `wait_for` | `name`, `selector` | `timeout` (default 10s) | `ok` |
| `watch` | `name`, `selector` | `timeout` (default 30s) | `ok`, `selector` |

`snapshot` with `format: "ai"` (default) returns `snapshot` field. With `format: "html"` returns `html` field. Both include `challenge` and `nonce`.

`nonce` is a server-generated hex string (16 chars) unique per response. It is present in every `snapshot` response regardless of `format`. Consumers can use it to delimit page-provided content — the page cannot forge or predict the value.

`wait_for` and `watch` both poll for a selector but are distinct wire commands: `wait_for` returns bare `ok` and is used as a programmatic blocking gate (default 10s); `watch` echoes back `selector` in its response and is designed for observational/interactive use (default 30s).

### HITL (Human-in-the-loop)

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `pause` | `name` | — | `ok`, `paused: true` |
| `resume` | `name` | — | `ok`, `paused: false` |

### Cookies

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `cookies` | `name` | — | `ok`, `cookies` (array) |
| `set_cookie` | `name`, `cookie_name`, `value`, `domain` | `path` (default `/`) | `ok` |
| `clear_cookies` | `name` | — | `ok` |
| `import_cookies` | `name`, `cookies` (array) | — | `ok`, `count` |

`export_cookies` has no wire command — it is implemented client-side by calling `cookies` then writing a file.

### DevTools

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `inspect` | `name` | — | `ok`, `devtools_url` |

### Daemon control

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `ping` | — | — | `ok`, `pid`, `protocol_version` |
| `shutdown` | — | — | `ok` |

---

## Stable zone — CLI reference

CLI command names and their flags. See [style-guide.md](style-guide.md) for the mapping from CLI names to wire names.

### Intentional aliases (documented, not bugs)

| CLI name | Maps to wire | Reason |
|----------|-------------|--------|
| `open` | `open_page` | brevity |
| `close` | `close_page` | brevity |
| `pages` | `list_pages` | brevity |
| `snap` | `snapshot` | brevity |
| `shot` | `screenshot` | brevity |
| `eval` | `evaluate` | brevity |
| `watch` | `watch` | 30s default, returns `selector` echo |

---

## Breaking changes before v0.5 (the lock)

| Issue | Status |
|-------|--------|
| CLI cookie commands used underscores (`set_cookie`, `clear_cookies`) | ✅ Fixed — renamed to `set-cookie`, `clear-cookies` |
| `ping` response lacked protocol version | ✅ Fixed — `protocol_version: "1"` added |
| `pause_resume.rb` grouped two commands in one file | ✅ Fixed — split into `pause.rb` and `resume.rb` |
| `REGISTRY` is a mutable constant | ⬜ v0.5 code item — thread-safe accessor |

`watch` was audited and **retained** as a distinct wire command. It differs from `wait_for` in both its default timeout (30s vs 10s) and its response shape (`selector:` echo vs bare `ok:`). The distinction is intentional and both are Fixed.

---

## Planned additions in v0.5 (still Fixed once added)

These wire commands do not exist yet — they are reserved names. Do not use them in plugins.

`store` and `fetch` already work today as workflow DSL methods (`WorkflowContext#store` / `#fetch`) for passing values between steps. The v0.5 work is promoting them to first-class wire protocol commands so non-Ruby clients can use them too.

| Wire command | Current status | Purpose |
|---|---|---|
| `store` | DSL only (`WorkflowContext`) | Set a named value in daemon-scoped state |
| `fetch` | DSL only (`WorkflowContext`) | Get a named value from daemon-scoped state |

---

## Protocol versioning

The `ping` response includes `protocol_version: "1"` (shipped in v0.4). Future incompatible protocol changes increment this number. Clients can check this field to negotiate capabilities.

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
- `Browserctl.socket_path`, `Browserctl.pid_path`, `Browserctl.log_path`

---

## Fixed zone — command reference

Every command that flows over the wire. Name, required params, optional params, and response fields are all Fixed once v0.6 ships.

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

### Cookies

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `cookies` | `name` | — | `ok`, `cookies` (array) |
| `set_cookie` | `name`, `cookie_name`, `value`, `domain` | `path` (default `/`) | `ok` |
| `delete_cookies` | `name` | — | `ok` |
| `import_cookies` | `name`, `cookies` (array) | — | `ok`, `count` |

`export_cookies` has no wire command — it is implemented client-side by calling `cookies` then writing a file.

### Storage

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `storage_get` | `name`, `key` | `store` (`"local"`\|`"session"`, default `"local"`) | `ok`, `value` |
| `storage_set` | `name`, `key`, `value` | `store` (default `"local"`) | `ok` |
| `storage_export` | `name`, `path` | `stores` (`"local"`\|`"session"`\|`"all"`, default `"all"`) | `ok`, `path`, `key_count` |
| `storage_import` | `name`, `path` | — | `ok`, `origins`, `key_count` |
| `storage_delete` | `name` | `stores` (default `"all"`) | `ok` |

### Session

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `session_save` | `session_name` | — | `ok`, `path`, `pages`, `cookies` |
| `session_load` | `session_name` | — | `ok`, `cookies`, `pages`, `local_storage_keys` |
| `session_list` | — | — | `ok`, `sessions` (array of metadata hashes) |
| `session_delete` | `session_name` | — | `ok` |

### DevTools

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `devtools` | `name` | — | `ok`, `devtools_url` |

### Daemon control

| Command | Required params | Optional params | Response fields |
|---------|----------------|----------------|-----------------|
| `ping` | — | — | `ok`, `pid`, `protocol_version` |
| `shutdown` | — | — | `ok` |
| `store` | `key`, `value` | — | `ok` |
| `fetch` | `key` | — | `ok`, `value` |

`fetch` returns `{ error: "key '<key>' not found", code: "key_not_found" }` when the key has never been stored. Values are scoped to the daemon process — they persist across `workflow run` invocations for as long as the daemon is running, and are lost when the daemon stops.

---

## Stable zone — CLI reference

CLI command names and their flags map 1-to-1 to wire commands via the subcommand routers in `lib/browserctl/commands/`. There are no abbreviation aliases — CLI names match their wire counterparts exactly.

---

## Breaking changes log

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
| — | `session_save/load/list/delete` | new (session persistence) |
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

# browserctl Style Guide

Naming and structural conventions for the browserctl codebase. These rules apply to all new code and are the target state for existing code.

---

## Naming by layer

browserctl has three distinct naming surfaces. Each has its own convention, and they do not need to match — but within each layer, naming must be consistent.

### Wire protocol (JSON-RPC command names)

`snake_case` always. These are the keys in `COMMAND_MAP` and what flows over the Unix socket.

```
page_open    page_close   page_list    page_focus
navigate     snapshot     screenshot
fill         click        evaluate
wait         url          ping
shutdown     pause        resume
devtools     cookies      set_cookie
delete_cookies            import_cookies
storage_get  storage_set  storage_export
storage_import            storage_delete
session_save session_load session_list
session_delete
store        fetch
```

Never abbreviate on the wire (`snapshot`, not `snap`; `navigate`, not `goto`). The wire protocol is the Fixed zone — these names cannot change without a `PROTOCOL_VERSION` bump.

### CLI commands (`bin/browserctl`)

v0.6 uses **noun-verb subcommand groups** for related commands and **full English words** for standalone verbs. No abbreviations; no aliases.

| CLI command | Wire command | Notes |
|---|---|---|
| `page open` | `page_open` | subcommand group |
| `page close` | `page_close` | subcommand group |
| `page list` | `page_list` | subcommand group |
| `page focus` | `page_focus` | subcommand group (headed mode only) |
| `navigate` | `navigate` | standalone verb |
| `snapshot` | `snapshot` | full word (no `snap` alias) |
| `screenshot` | `screenshot` | full word (no `shot` alias) |
| `evaluate` | `evaluate` | full word (no `eval` alias) |
| `fill` | `fill` | standalone |
| `click` | `click` | standalone |
| `url` | `url` | standalone |
| `wait` | `wait` | standalone |
| `pause` | `pause` | standalone |
| `resume` | `resume` | standalone |
| `devtools` | `devtools` | standalone |
| `cookie list` | `cookies` | subcommand group |
| `cookie set` | `set_cookie` | subcommand group |
| `cookie delete` | `delete_cookies` | subcommand group |
| `cookie export` | client-side | reads `cookies`, writes file |
| `cookie import` | `import_cookies` | subcommand group |
| `storage get` | `storage_get` | subcommand group |
| `storage set` | `storage_set` | subcommand group |
| `storage export` | `storage_export` | subcommand group |
| `storage import` | `storage_import` | subcommand group |
| `storage delete` | `storage_delete` | subcommand group |
| `session save` | `session_save` | subcommand group |
| `session load` | `session_load` | subcommand group |
| `session list` | `session_list` | subcommand group |
| `session delete` | `session_delete` | subcommand group |
| `session export` | client-side | zips session directory |
| `session import` | client-side | unzips session archive |
| `daemon ping` | `ping` | subcommand group |
| `daemon status` | client-side | reads `ping` + `page_list` + `url` per page |
| `daemon start` | client-side | spawns `browserd` subprocess |
| `daemon stop` | `shutdown` | subcommand group |
| `daemon list` | client-side | scans sockets, pings each |
| `workflow run` | client-side | runs a workflow file or name |
| `workflow list` | client-side | lists registered workflows |
| `workflow describe` | client-side | shows params + steps |

**Rules:**
- Subcommand groups follow `<noun> <verb>` order.
- Standalone verbs (not grouped) are full English words with no abbreviation alias.
- No hyphenated names — use spaces (subcommands) or underscores (wire).

### Ruby SDK (`Browserctl::Client` methods)

`snake_case` always. Full names preferred over abbreviations. Method names follow the wire command names.

```ruby
page_open    page_close   page_list    page_focus
navigate     snapshot     screenshot
fill         click        evaluate
wait         url
pause        resume       devtools
cookies      set_cookie   delete_cookies
export_cookies            import_cookies
storage_get  storage_set  storage_export
storage_import            storage_delete
session_save session_load session_list
session_delete
store        fetch
ping         shutdown
```

---

## File naming

| Context | Convention | Example |
|---------|-----------|---------|
| Ruby source | `snake_case.rb` | `command_dispatcher.rb` |
| Command handler | one command per file, named after the wire command | `snapshot.rb`, `screenshot.rb` |
| Spec files | mirror source path, `_spec.rb` suffix | `spec/unit/snapshot_spec.rb` |
| Docs | `kebab-case.md` | `api-stability.md` |

One command handler = one file. Do not group paired commands in a single file.

---

## Module and class naming

`PascalCase` for modules and classes. `snake_case` for methods, local variables, and symbols.

```ruby
module Browserctl
  class CommandDispatcher   # PascalCase
    COMMAND_MAP = {}.freeze # SCREAMING_SNAKE for module-level constants

    def cmd_snapshot(req)   # snake_case, cmd_ prefix for dispatcher handlers
    end
  end
end
```

---

## Wire response shapes

Every response is one of two shapes — no exceptions:

```json
{ "ok": true, ...data fields }
{ "error": "lowercase description of what went wrong" }
```

Rules:
- `ok` is always boolean `true` — never `"true"` or `1`
- `error` is always a lowercase string — no capitalisation, no trailing period
- Do not mix both `ok` and `error` in the same response
- Required data fields per command are documented in [api-stability.md](api-stability.md)

Error message format: `"<what failed>: <reason or value>"` — e.g. `"no page named 'main'"`, `"selector not found: #submit"`.

---

## CLI output

All CLI commands print a single JSON object to stdout on success. Errors go to stderr via `warn`. Exit codes: `0` success, `1` error.

```ruby
# success
puts res.to_json

# error
warn "Error: #{res[:error]}"
exit 1
```

---

## Workflow DSL

Workflow files are plain Ruby. Naming rules:

- Workflow names: `snake_case` symbol — `:checkout_smoke`, `:login_flow`
- Step labels: free-form strings, written in imperative — `"navigate to login"`, `"fill credentials"`
- Param names: `snake_case` symbol — `param :email`, `param :api_key`

---

## Constants

Module-level mutable state is forbidden. All constants are frozen.

```ruby
COMMAND_MAP = { ... }.freeze   # ✓
```

Shared registries (workflow definitions, plugin commands) use mutex-protected module-level accessors — not mutable constants. Use `Browserctl.register_command` / `Browserctl.lookup_plugin_command` and `Browserctl.workflow` / `Browserctl.lookup_workflow` rather than mutating a constant directly.

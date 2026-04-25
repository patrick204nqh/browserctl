# browserctl Style Guide

Naming and structural conventions for the browserctl codebase. These rules apply to all new code and are the target state for existing code.

---

## Naming by layer

browserctl has three distinct naming surfaces. Each has its own convention, and they do not need to match — but within each layer, naming must be consistent.

### Wire protocol (JSON-RPC command names)

`snake_case` always. These are the keys in `COMMAND_MAP` and what flows over the Unix socket.

```
open_page   close_page   list_pages
goto        snapshot      screenshot
fill        click         evaluate
wait_for    url           ping
shutdown    pause         resume
inspect     cookies       set_cookie
clear_cookies             import_cookies
```

Never abbreviate on the wire (`snapshot`, not `snap`). The wire protocol is the Fixed zone — once locked, these names never change.

### CLI commands (`bin/browserctl`)

Lowercase, hyphen-separated for multi-word names. Single-word commands are their natural verb or noun.

Short-form aliases are allowed **and intentional** — document them explicitly, do not treat them as bugs.

| Canonical CLI name | Wire command | Notes |
|--------------------|--------------|-------|
| `open` | `open_page` | concise alias |
| `close` | `close_page` | concise alias |
| `pages` | `list_pages` | concise alias |
| `goto` | `goto` | — |
| `snap` | `snapshot` | short-form alias; `--format ai` is the default |
| `shot` | `screenshot` | short-form alias |
| `fill` | `fill` | — |
| `click` | `click` | — |
| `eval` | `evaluate` | short-form alias |
| `url` | `url` | — |
| `watch` | `watch` | 30s default, returns selector echo |
| `pause` | `pause` | — |
| `resume` | `resume` | — |
| `inspect` | `inspect` | — |
| `cookies` | `cookies` | — |
| `set-cookie` | `set_cookie` | hyphen (not `set_cookie`) |
| `clear-cookies` | `clear_cookies` | hyphen (not `clear_cookies`) |
| `export-cookies` | client-side | hyphen ✓ |
| `import-cookies` | `import_cookies` | hyphen ✓ |
| `ping` | `ping` | — |
| `shutdown` | `shutdown` | — |

**Rule:** multi-word CLI commands are always hyphenated. Underscores are forbidden in CLI command names.

### Ruby SDK (`Browserctl::Client` methods)

`snake_case` always. Full names preferred over abbreviations. The sole exception is `inspect_page` (avoids shadowing `Kernel#inspect`).

```ruby
open_page    close_page   list_pages
goto         snapshot     screenshot
fill         click        evaluate
wait_for     watch        url
pause        resume       inspect_page
cookies      set_cookie   clear_cookies
export_cookies            import_cookies
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

One command handler = one file. Do not group paired commands (e.g. `pause_resume.rb`) in a single file.

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
REGISTRY = {}                  # ✗ — mutable constant (flagged for v0.5)
```

Plugin commands go through the `PLUGIN_COMMANDS` registry — not raw constant mutation.

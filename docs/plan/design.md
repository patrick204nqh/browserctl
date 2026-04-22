# Design Document — browserctl v0.4 Hardening

## Overview

Six targeted changes to browserctl's existing architecture. No new subsystems are introduced — all changes extend or tighten existing components: `WorkflowContext`, `Recording`, `Client`, `CommandDispatcher`, `Runner`, and the CLI command layer. The design follows the existing patterns: thin CLI commands, a JSON-RPC client/server split, and a Ruby DSL for workflows.

## System Architecture

### Component Map (affected components only)

| Component ID | Name | Type | Change | Interfaces With |
|---|---|---|---|---|
| COMP-1 | `browserctl.gemspec` | Config | Version pin edit | — |
| COMP-2 | `Recording` | Library | File permissions + URL redaction | `Client` |
| COMP-3 | `WorkflowContext` | Library | Add `store`/`fetch` | `WorkflowDefinition` |
| COMP-4 | `Client` | Library | Add `export_cookies`, `import_cookies` | `CommandDispatcher` |
| COMP-5 | `CommandDispatcher` | Server | Add `cmd_import_cookies` bulk handler | `Client` |
| COMP-6 | `Runner` | Library | Add `--params` file loading | CLI command |
| COMP-7 | CLI commands | CLI | Add `export-cookies`, `import-cookies` subcommands | `Client` |

### High-Level Architecture (unchanged components omitted)

```
browserctl CLI
   ├── run.rb ──────────────── Runner ─────────────── WorkflowContext (+ store/fetch)
   │   └── --params <file>                                   │
   │                                                  WorkflowDefinition
   │
   ├── record.rb ────────────── Recording (0600 perms, URL redact)
   │
   ├── export-cookies.rb ──┐
   ├── import-cookies.rb ──┤── Client ── Unix socket ── CommandDispatcher
   │                       │               (JSON-RPC)   └── cmd_import_cookies
   └── ...existing cmds ───┘
```

---

## Components and Interfaces

### COMP-1 — `browserctl.gemspec`

**Change:** Single line — `required_ruby_version = ">= 3.3"`.

**File:** `browserctl.gemspec:24`

---

### COMP-2 — `Recording` (lib/browserctl/recording.rb)

**Change A — Secure file permissions:**

```ruby
def self.start(name)
  FileUtils.mkdir_p(RECORDINGS_DIR, mode: 0o700)
  FileUtils.mkdir_p(File.dirname(STATE_FILE))
  File.write(STATE_FILE, name)
  FileUtils.rm_f(log_path(name))
  FileUtils.touch(log_path(name))
  File.chmod(0o600, log_path(name))   # NEW
  name
end
```

**Change B — URL redaction in `append`:**

```ruby
SENSITIVE_PARAM_PATTERN = /\A(token|key|secret|auth|code|access_token|
                              api_key|client_secret|state)\z/ix

def self.redact_url(url)
  uri = URI.parse(url)
  return url if uri.query.nil?
  params = URI.decode_www_form(uri.query).map do |k, v|
    k =~ SENSITIVE_PARAM_PATTERN ? [k, "[REDACTED]"] : [k, v]
  end
  uri.query = URI.encode_www_form(params)
  uri.to_s
rescue URI::InvalidURIError
  url
end
```

Call `redact_url` on the `:url` field only when `cmd == "goto"` or `cmd == "open_page"`.

Generated step comment when redaction occurs:

```ruby
# NOTE: sensitive query params were redacted during recording
step "goto #{page}" do
  page(:#{page}).goto("https://example.com/auth?code=[REDACTED]")
end
```

---

### COMP-3 — `WorkflowContext` (lib/browserctl/workflow.rb)

**Change — Add `store`/`fetch`:**

```ruby
class WorkflowContext
  def initialize(params, client)
    @params  = params
    @client  = client
    @_store  = {}   # NEW: cross-step state
  end

  def store(key, value)   # NEW
    @_store[key] = value
  end

  def fetch(key)          # NEW
    @_store.fetch(key) { raise KeyError, "no value stored for key #{key.inspect}" }
  end

  # ... existing methods unchanged
end
```

**Design note:** `store`/`fetch` keys are independent of `param` names. `method_missing` handles params; `store`/`fetch` are explicit named methods. No collision risk unless the author stores a key that shadows a method name (which Ruby would not route through `method_missing` anyway).

---

### COMP-4 — `Client` (lib/browserctl/client.rb)

**New methods:**

```ruby
def export_cookies(name, path)
  result = call("cookies", name: name)
  return result unless result[:ok]
  File.write(path, JSON.generate(result[:cookies]))
  { ok: true, path: path, count: result[:cookies].length }
end

def import_cookies(name, path)
  raise "params file not found: #{path}" unless File.exist?(path)
  cookies = JSON.parse(File.read(path), symbolize_names: true)
  call("import_cookies", name: name, cookies: cookies)
end
```

`export_cookies` is client-side only (uses existing `cmd_cookies`). `import_cookies` sends a new `import_cookies` command to the server.

---

### COMP-5 — `CommandDispatcher` (lib/browserctl/server/command_dispatcher.rb)

**New command handler:**

```ruby
def cmd_import_cookies(req)
  with_page(req) do |session|
    req[:cookies].each do |c|
      session.page.cookies.set(
        name:     c[:name],
        value:    c[:value],
        domain:   c[:domain],
        path:     c.fetch(:path, "/"),
        httponly: c[:httpOnly],
        secure:   c[:secure],
        expires:  c[:expires] ? Time.at(c[:expires].to_i) : nil
      )
    end
    { ok: true, count: req[:cookies].length }
  end
end
```

Register in `dispatch` switch: `"import_cookies" => :cmd_import_cookies`.

---

### COMP-6 — `Runner` (lib/browserctl/runner.rb)

**Change — Load params file before CLI param merge:**

```ruby
def self.load_params_file(path)
  raise "params file not found: #{path}" unless File.exist?(path)
  case File.extname(path).downcase
  when ".yml", ".yaml"
    require "yaml"
    YAML.safe_load_file(path, symbolize_names: true)
  when ".json"
    JSON.parse(File.read(path), symbolize_names: true)
  else
    raise "unsupported params file format: #{path} (use .yml, .yaml, or .json)"
  end
rescue Psych::SyntaxError => e
  raise "invalid YAML in #{path}: #{e.message}"
rescue JSON::ParserError => e
  raise "invalid JSON in #{path}: #{e.message}"
end
```

Merge order in `run_workflow`: `file_params.merge(cli_params)` — CLI wins.

---

### COMP-7 — CLI commands

**New file: `lib/browserctl/commands/export_cookies.rb`**

```ruby
opts = Optimist.options { banner "Usage: browserctl export-cookies <page> <path>" }
page, path = ARGV.shift, ARGV.shift
Browserctl::CliOutput.print(Browserctl::Client.new.export_cookies(page, path))
```

**New file: `lib/browserctl/commands/import_cookies.rb`**

```ruby
opts = Optimist.options { banner "Usage: browserctl import-cookies <page> <path>" }
page, path = ARGV.shift, ARGV.shift
Browserctl::CliOutput.print(Browserctl::Client.new.import_cookies(page, path))
```

Wire both into the main `bin/browserctl` command dispatcher alongside existing subcommands.

---

## Data Flow — Cookie Export/Import

Session files live under `.browserctl/sessions/` in the project directory (same convention as `.browserctl/workflows/` and `.browserctl/screenshots/`). This keeps sessions scoped to the project that authenticates them and makes the path easy to reference with a relative path in workflows.

```
Export:
  CLI: browserctl export-cookies main .browserctl/sessions/site.json
    → Client#export_cookies("main", path)
      → call("cookies", name: "main")        # existing command
        → CommandDispatcher#cmd_cookies
          → Ferrum page.cookies.all.values.map(&:to_h)
      ← { ok: true, cookies: [...] }
    → File.write(path, JSON.generate(cookies))

Import:
  CLI: browserctl import-cookies main .browserctl/sessions/site.json
    → Client#import_cookies("main", path)
      → JSON.parse(File.read(path))
      → call("import_cookies", name: "main", cookies: [...])
        → CommandDispatcher#cmd_import_cookies
          → session.page.cookies.set(...) × N
          ← { ok: true, count: N }
```

---

## Data Models

### Cookie JSON schema (export format)

```json
[
  {
    "name": "session_token",
    "value": "abc123",
    "domain": ".example.com",
    "path": "/",
    "httpOnly": true,
    "secure": true,
    "expires": 1777000000
  }
]
```

`expires` is a Unix timestamp integer (or `null` for session cookies). This matches Ferrum's `Cookie#to_h` output shape with minor normalization.

---

## Error Handling

| Scenario | Handling |
|---|---|
| `fetch(:missing_key)` in workflow | `KeyError` with key name — surfaces in step failure output |
| `import-cookies` file not found | `Client#import_cookies` raises before socket call; CLI prints error and exits 1 |
| Params file not found | `Runner.load_params_file` raises; `run.rb` rescues and prints error, exits 1 |
| Invalid YAML/JSON in params file | Rescue `Psych::SyntaxError` / `JSON::ParserError`, print message, exit 1 |
| `redact_url` on malformed URL | `rescue URI::InvalidURIError` — return original URL unchanged |

---

## Security Considerations

- JSONL files created with `0600` — readable only by the owner process user
- Recordings directory created with `0700`
- Cookie export files use project-local `.browserctl/sessions/` — git-ignored at the project level (added by `browserctl init`), consistent with the existing `.browserctl/` convention
- Params files should be git-ignored; the `--params` flag does not enforce this, but README will note it
- URL redaction is best-effort (pattern-based); unusual token param names may not be caught — this is documented as a known limitation

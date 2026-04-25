# Command Reference

All commands require `browserd` to be running unless noted.

---

## Setup commands

| Command | Description |
|---|---|
| `init` | Scaffold `.browserctl/` in the current project (does not require `browserd`) |

---

## Browser commands

| Command | Description |
|---|---|
| `open <page> [--url URL]` | Open or focus a named page |
| `close <page>` | Close a named page |
| `pages` | List open pages |
| `goto <page> <url>` | Navigate a page to a URL |
| `fill <page> <selector> <value>` | Fill an input field by CSS selector |
| `fill <page> --ref <id> --value <v>` | Fill an input field by snapshot ref |
| `click <page> <selector>` | Click an element by CSS selector |
| `click <page> --ref <id>` | Click an element by snapshot ref |
| `snap <page> [--format elements\|html] [--diff]` | Snapshot DOM; `--diff` returns only changed elements |
| `watch <page> <selector> [--timeout N]` | Poll until selector appears (default timeout: 30s) |
| `shot <page> [--out PATH] [--full]` | Take a screenshot |
| `url <page>` | Print current URL |
| `eval <page> <expression>` | Evaluate a JS expression |
| `pause <page>` | Pause automation — browser stays live for manual interaction |
| `resume <page>` | Resume automation after manual action |
| `inspect <page>` | Open Chrome DevTools for a named page |
| `cookies <page>` | List all cookies as JSON |
| `set-cookie <page> <name> <value> <domain>` | Set a cookie (path defaults to `/`) |
| `clear-cookies <page>` | Clear all cookies for a page |
| `export-cookies <page> <path>` | Export all cookies to a JSON file |
| `import-cookies <page> <path>` | Import cookies from a JSON file |
| `record start <name>` | Begin recording commands as a replayable workflow |
| `record stop [--out path]` | End recording; saves to `.browserctl/workflows/` or custom path |
| `record status` | Show whether a recording is active |

---

## Daemon commands

| Command | Description |
|---|---|
| `ping` | Check if `browserd` is alive — returns `{ ok: true, pid: N, protocol_version: "1" }` |
| `status` | Show daemon status, PID, and all open pages with their current URLs |
| `shutdown` | Stop `browserd` |

`browserctl status` response:

```json
{ "daemon": "online", "pid": 12345, "protocol_version": "1", "pages": [
  { "name": "main", "url": "https://app.example.com/dashboard" }
]}
```

When the daemon is not running:

```json
{ "daemon": "offline", "error": "browserd is not running — start it with: browserd" }
```

---

## Workflow commands

| Command | Description |
|---|---|
| `run <name\|file.rb> [--params file] [--key value ...]` | Run a named workflow or workflow file |
| `workflows` | List available workflows |
| `describe <name>` | Show workflow params and steps |

---

## `browserd` flags

| Flag | Default | Description |
|---|---|---|
| `--headed` | headless | Start with a visible browser window |
| `--name <id>` | `default` | Name this daemon instance (for multi-agent isolation) |
| `--log-level <level>` | `info` | Log verbosity: `debug`, `info`, `warn`, `error` |

`browserd` always writes logs to `~/.browserctl/browserd.log` (or `~/.browserctl/<name>.log` for a named instance) in addition to stderr. The log path is printed to stderr on startup so it's visible even when backgrounding with `&`:

```
browserd starting — log: /Users/you/.browserctl/browserd.log
```

To follow live log output:

```bash
tail -f ~/.browserctl/browserd.log
```

If a daemon is already running when `browserd` starts, it aborts with a clear message rather than clobbering the live session:

```
browserd already running (PID 12345). Use 'browserctl shutdown' first.
```

---

## `browserctl` global flags

| Flag | Description |
|---|---|
| `--daemon <name>` | Target a specific named daemon instance |

---

## Snapshot format

`browserctl snap <page>` returns a JSON array of interactable elements:

```json
[
  {
    "ref": "e1",
    "tag": "input",
    "text": "",
    "selector": "form > input[name=email]",
    "attrs": {
      "type": "email",
      "name": "email",
      "placeholder": "Enter email"
    }
  },
  {
    "ref": "e2",
    "tag": "button",
    "text": "Sign in",
    "selector": "form > button",
    "attrs": { "type": "submit" }
  }
]
```

Use `--ref <id>` with `fill` and `click` to interact without writing selectors. Use `--format html` for full page HTML.

`goto` and `snap` responses include `"challenge": true` when a Cloudflare interstitial is detected. See [Handling Challenges](../guides/handling-challenges.md).

---

## Workflow DSL reference

| Method | Description |
|---|---|
| `desc "text"` | Human-readable description shown by `browserctl workflows` |
| `param :name, required:, secret:, default:` | Declare an input parameter |
| `step "label" { }` | Add a step — runs in order, halts workflow on failure |
| `step "label", retry_count: N, timeout: S { }` | Step with retry and/or timeout |
| `compose "workflow"` | Inline all steps from another workflow at this point |
| `open_page(page_name, url: nil)` | Open a named page, optionally navigating to a URL |
| `close_page(page_name)` | Close a named page |
| `page(:name)` | Return a `PageProxy` for the named page |
| `invoke "workflow", **overrides` | Call another workflow by name (runs as a unit, not inlined) |
| `assert condition, "message"` | Raise `WorkflowError` if condition is false |
| `store :key, value` | Store a value for use in later steps (within this run only) |
| `fetch :key` | Retrieve a value stored by an earlier step |

---

## PageProxy methods

Methods available on `page(:name)` inside a workflow:

| Method | Description |
|---|---|
| `goto(url)` | Navigate to URL |
| `fill(selector, value)` | Fill an input by CSS selector |
| `click(selector)` | Click an element by CSS selector |
| `watch(selector, timeout: 30)` | Poll until selector appears (default 30s) — use for async content |
| `wait_for(selector, timeout: 10)` | Wait up to N seconds for selector to appear (short-form gate, default 10s) |
| `url` | Return the current page URL |
| `evaluate(expression)` | Evaluate a JS expression and return the result |
| `snapshot(**opts)` | Return a DOM snapshot (same as `browserctl snap`) |
| `screenshot(**opts)` | Take a screenshot (same as `browserctl shot`) |

Prefer `watch` for async content that may take several seconds to appear; use `wait_for` as a quick gate for DOM already expected to be present.

For the full workflow authoring guide, see [Writing Workflows](../guides/writing-workflows.md).

# Command Reference

All commands require `browserd` to be running unless noted.

---

## Setup

| Command | Description |
|---|---|
| `init` | Scaffold `.browserctl/` in the current project (does not require `browserd`) |

---

## Page

| Command | Description |
|---|---|
| `page open <name> [--url URL]` | Open a named browser tab, optionally navigating to a URL |
| `page close <name>` | Close a named tab |
| `page list` | List all open named pages and their current URLs |
| `page focus <name>` | Bring a tab to front (headed mode only) |

---

## Interaction

Page is always the first argument after the verb.

| Command | Description |
|---|---|
| `navigate <page> <url>` | Navigate a page to a URL |
| `fill <page> <selector> <value>` | Fill an input field by CSS selector |
| `fill <page> --ref <id> --value <v>` | Fill an input field by snapshot ref |
| `click <page> <selector>` | Click an element by CSS selector |
| `click <page> --ref <id>` | Click an element by snapshot ref |
| `snapshot <page> [--format elements\|html] [--diff]` | Snapshot DOM; `--diff` returns only changed elements |
| `screenshot <page> [--out PATH] [--full]` | Take a screenshot |
| `evaluate <page> <expression>` | Evaluate a JavaScript expression |
| `url <page>` | Print the current URL |
| `wait <page> <selector> [--timeout N]` | Wait until selector appears (default: 30s) |
| `pause <page> [--message MSG]` | Pause automation — browser stays live for manual interaction |
| `resume <page>` | Resume automation after manual action |
| `devtools <page>` | Open Chrome DevTools for a named page |

`navigate` and `snapshot` responses include `"challenge": true` when a Cloudflare interstitial is detected. See [Handling Challenges](../guides/handling-challenges.md).

---

## Cookie

| Command | Description |
|---|---|
| `cookie list <page>` | List all cookies as JSON |
| `cookie set <page> <name> <value> --domain DOMAIN [--path /]` | Set a cookie |
| `cookie delete <page>` | Delete all cookies for a page |
| `cookie export <page> <path>` | Export all cookies to a JSON file |
| `cookie import <page> <path>` | Import cookies from a JSON file |

---

## Storage

| Command | Description |
|---|---|
| `storage get <page> <key> [--store local\|session]` | Read a localStorage or sessionStorage key |
| `storage set <page> <key> <value> [--store local\|session]` | Write a localStorage or sessionStorage key |
| `storage export <page> <path> [--store local\|session\|all]` | Export storage to a JSON file |
| `storage import <page> <path>` | Import storage keys from a JSON file |
| `storage delete <page> [--store local\|session\|all]` | Clear localStorage and/or sessionStorage |

`--store` defaults to `local`. The export format is `{ "https://origin": { key: value } }`.

---

## Session

A session bundles everything needed to resume a browser state: all open pages (names + URLs), all cookies, and localStorage for each origin. Session files are plain JSON stored in `~/.browserctl/sessions/<name>/`.

| Command | Description |
|---|---|
| `session save <name>` | Save the current browser state to a named session |
| `session load <name>` | Restore a saved session into the running daemon |
| `session list` | List all saved sessions |
| `session delete <name>` | Delete a saved session |
| `session export <name> <path>` | Zip a saved session to a portable archive |
| `session import <path>` | Unzip a session archive into the sessions directory |

---

## Recording

| Command | Description |
|---|---|
| `record start <name>` | Begin recording commands as a replayable workflow |
| `record stop [--out PATH]` | End recording; saves to `.browserctl/workflows/` or custom path |
| `record status` | Show whether a recording is active |

---

## Workflow

| Command | Description |
|---|---|
| `workflow run <name\|file.rb> [--params file] [--key value ...]` | Run a named workflow or workflow file |
| `workflow list` | List all discoverable workflows with descriptions |
| `workflow describe <name>` | Show params and step labels for a workflow |

---

## Daemon

| Command | Description |
|---|---|
| `daemon ping` | Check if `browserd` is alive — returns `{ ok: true, pid: N, protocol_version: "2" }` |
| `daemon status` | Show daemon status, PID, and all open pages with their current URLs |
| `daemon start [--headed] [--name NAME]` | Start a new `browserd` instance in the background |
| `daemon stop` | Stop the running `browserd` gracefully |
| `daemon list` | List all running daemon instances with name, PID, and page count |

`daemon status` response:

```json
{ "daemon": "online", "pid": 12345, "protocol_version": "2", "pages": [
  { "name": "main", "url": "https://app.example.com/dashboard" }
]}
```

When the daemon is not running:

```json
{ "daemon": "offline", "error": "browserd is not running — start it with: browserd" }
```

---

## `browserd` flags

| Flag | Default | Description |
|---|---|---|
| `--headed` | headless | Start with a visible browser window |
| `--name <id>` | auto | Name this daemon instance; if omitted and the default slot is taken, auto-picks `d1`, `d2`, ... |
| `--log-level <level>` | `info` | Log verbosity: `debug`, `info`, `warn`, `error` |

`browserd` always writes logs to `~/.browserctl/browserd.log` (or `~/.browserctl/<name>.log` for a named instance). The log path is printed to stderr on startup:

```
browserd starting — log: /Users/you/.browserctl/browserd.log
```

To follow live log output:

```bash
tail -f ~/.browserctl/browserd.log
```

When the default slot is already taken, `browserd` auto-indexes rather than aborting:

```
browserd: default slot taken — starting as 'd1'
  to connect: browserctl --daemon d1 <command>
```

---

## `browserctl` global flags

| Flag | Description |
|---|---|
| `--daemon <name>` | Connect to a specific named or auto-indexed daemon (e.g. `d1`, `work`) |
| `--version, -v` | Print the version and exit |

If `--daemon` is omitted, `browserctl` connects to the default socket (`browserd.sock`). If that socket is absent, it falls back to the first responsive auto-indexed daemon and prints which one it connected to.

---

## Snapshot format

`browserctl snapshot <page>` returns a JSON array of interactable elements:

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

---

## Workflow DSL reference

| Method | Description |
|---|---|
| `desc "text"` | Human-readable description shown by `workflow list` |
| `param :name, required:, secret:, default:` | Declare an input parameter |
| `step "label" { }` | Add a step — runs in order, halts workflow on failure |
| `step "label", retry_count: N, timeout: S { }` | Step with retry and/or timeout |
| `compose "workflow"` | Inline all steps from another workflow at this point |
| `open_page(name, url: nil)` | Open a named page, optionally navigating to a URL |
| `close_page(name)` | Close a named page |
| `page(:name)` | Return a `PageProxy` for the named page |
| `save_session(name)` | Save the current browser state to a named session |
| `load_session(name)` | Restore a saved session into the running daemon |
| `list_sessions` | Return all saved session metadata |
| `invoke "workflow", **overrides` | Call another workflow by name |
| `assert condition, "message"` | Raise `WorkflowError` if condition is false |
| `store :key, value` | Store a value for use in later steps |
| `fetch :key` | Retrieve a value stored by an earlier step |

---

## PageProxy methods

Methods available on `page(:name)` inside a workflow:

| Method | Description |
|---|---|
| `navigate(url)` | Navigate to a URL |
| `fill(selector, value)` | Fill an input by CSS selector |
| `click(selector)` | Click an element by CSS selector |
| `wait(selector, timeout: 30)` | Wait until selector appears (default 30s) |
| `url` | Return the current page URL |
| `evaluate(expression)` | Evaluate a JS expression and return the result |
| `snapshot(**opts)` | Return a DOM snapshot |
| `screenshot(**opts)` | Take a screenshot |
| `storage_get(key, store: "local")` | Read a localStorage or sessionStorage key |
| `storage_set(key, value, store: "local")` | Write a localStorage or sessionStorage key |
| `delete_cookies` | Delete all cookies for the page |
| `devtools` | Return the Chrome DevTools URL for this page |

All methods raise `WorkflowError` on a daemon error, which fails the current step.

For the full workflow authoring guide, see [Writing Workflows](../guides/writing-workflows.md).

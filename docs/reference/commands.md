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
| `press <page> <key>` | Fire a `keydown` + `keyup` event for the given key |
| `hover <page> <selector>` | Move the mouse cursor to the centre of the matched element |
| `upload <page> <selector> <file>` | Set a `<input type="file">` element's value to a file path |
| `select <page> <selector> <value>` | Set a `<select>` element's value and fire a `change` event |
| `dialog accept <page> [text]` | Pre-register a one-shot handler to accept the next JS dialog |
| `dialog dismiss <page>` | Pre-register a one-shot handler to dismiss the next JS dialog |
| `ask <prompt>` | Pause and prompt the human for a value via stdin |

`navigate` and `snapshot` responses include `"challenge": true` when a Cloudflare interstitial is detected. See [Handling Challenges](../guides/handling-challenges.md).

### `press <page> <key>`

Fires a `keydown` + `keyup` event for the given key. `key` is any Chrome key name: `Enter`, `Tab`, `Escape`, `ArrowDown`, `Backspace`, or a single character like `a`.

```sh
browserctl press main Enter
browserctl press main Tab
```

### `hover <page> <selector>`

Moves the mouse cursor to the centre of the element matched by `selector`.

```sh
browserctl hover main "#dropdown-trigger"
```

### `upload <page> <selector> <file>`

Sets a `<input type="file">` element's value to `file`.

```sh
browserctl upload main "#resume-input" /path/to/resume.pdf
```

### `select <page> <selector> <value>`

Sets a `<select>` element's value and fires a `change` event.

```sh
browserctl select main "#country" "AU"
```

### `dialog accept <page> [text]`

Pre-registers a one-shot handler to accept the next JavaScript dialog (`alert`, `confirm`, `prompt`). Call this **before** the action that triggers the dialog. `text` is only used for `prompt` dialogs.

```sh
browserctl dialog accept main
browserctl dialog accept main "my-prompt-answer"
```

### `dialog dismiss <page>`

Pre-registers a one-shot handler to dismiss the next JavaScript dialog.

```sh
browserctl dialog dismiss main
```

### `ask <prompt>`

Pauses execution and prompts the human for a value via stdin. Output is JSON `{ "ok": true, "value": "..." }`. Prompt is written to stderr so it doesn't pollute stdout JSON.

```sh
browserctl ask "Enter 2FA code:"
```

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

A session bundles everything needed to resume a browser state: all open pages (names + URLs), all cookies, and localStorage for each origin. Session files live in `~/.browserctl/sessions/<name>/`. By default they are plain JSON with `0o600` permissions; `--encrypt` stores them as AES-256-GCM blobs with the key in macOS Keychain.

| Command | Description |
|---|---|
| `session save <name> [--encrypt]` | Save the current browser state; `--encrypt` stores sensitive files as AES-256-GCM blobs (macOS only) |
| `session load <name>` | Restore a saved session into the running daemon |
| `session list` | List all saved sessions |
| `session delete <name>` | Delete a saved session |
| `session export <name> <path> [--encrypt]` | Zip a session to a portable archive; `--encrypt` prompts for a passphrase and uses PBKDF2+AES-256-GCM |
| `session import <path>` | Unzip a session archive; automatically detects and decrypts an encrypted archive |

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
| `param :name, secret_ref: "scheme://ref"` | Declare a param sourced from a secret manager at runtime; always masked from recordings |
| `step "label" { }` | Add a step — runs in order, halts workflow on failure |
| `step "label", retry_count: N, timeout: S { }` | Step with retry and/or timeout |
| `compose "workflow"` | Inline all steps from another workflow at this point |
| `open_page(name, url: nil)` | Open a named page, optionally navigating to a URL |
| `close_page(name)` | Close a named page |
| `page(:name)` | Return a `PageProxy` for the named page |
| `save_session(name, encrypt: false)` | Save the current browser state; `encrypt: true` uses macOS Keychain (darwin only) |
| `load_session(name, fallback: nil)` | Restore a saved session; `fallback:` names a workflow to run and retry if the session is missing |
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
| `press(key)` | Fire a `keydown` + `keyup` event for the given key |
| `hover(selector)` | Move the mouse to the centre of the matched element |
| `upload(selector, path)` | Set a file input's value to a file path |
| `select(selector, value)` | Set a `<select>` element's value and fire a `change` event |

All methods raise `WorkflowError` on a daemon error, which fails the current step.

For the full workflow authoring guide, see [Writing Workflows](../guides/writing-workflows.md).

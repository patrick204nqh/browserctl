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
| `snap <page> [--format ai\|html] [--diff]` | Snapshot DOM; `--diff` returns only changed elements |
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
| `ping` | Check if `browserd` is alive |
| `shutdown` | Stop `browserd` |

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
| `wait_for(selector, timeout: 10)` | Wait up to N seconds for selector to appear |
| `url` | Return the current page URL |
| `evaluate(expression)` | Evaluate a JS expression and return the result |
| `snapshot(**opts)` | Return a DOM snapshot (same as `browserctl snap`) |
| `screenshot(**opts)` | Take a screenshot (same as `browserctl shot`) |

For the full workflow authoring guide, see [Writing Workflows](../guides/writing-workflows.md).

---
name: browserctl
description: Control a persistent browser daemon with discrete shell commands. Use for web automation, AI agent browser tasks, login flows, form filling, screenshots, and replayable Ruby workflows.
user-invocable: false
---

# browserctl — AI agent skill

## What this is

`browserctl` gives you a persistent browser you can control with discrete shell commands.
The browser state (open tabs, cookies, localStorage) survives between commands — you don't
restart the browser on every action.

## Starting the daemon

```
browserd &         # headless (default)
browserd --headed  # shows the browser window
```

Or start it through the CLI (spawns in background automatically):

```sh
browserctl daemon start
browserctl daemon start --headed
browserctl daemon start --name work
```

Check it's alive: `browserctl daemon ping`

Logs are written to `~/.browserctl/browserd.log` — the path is printed on startup. Tail it when debugging: `tail -f ~/.browserctl/browserd.log`

If the default socket is already taken, `browserd` auto-indexes rather than aborting:

```
browserd: default slot taken — starting as 'd1'
  to connect: browserctl --daemon d1 <command>
```

List all running daemons: `browserctl daemon list`

## Core workflow

1. Open a named page (name describes purpose, e.g. `login`, `checkout`)
2. Navigate, fill, click using discrete commands
3. Use `snapshot` when you don't know the layout — `--format elements` is the default
4. When a sequence stabilises, save it as a workflow

## Commands

```sh
# Navigation
browserctl page open  login --url https://app.example.com/login
browserctl navigate   login https://app.example.com/other
browserctl url        login

# Interaction — by selector
browserctl fill  login "input[name=email]"    user@example.com
browserctl fill  login "input[name=password]" secret
browserctl click login "button[type=submit]"

# Interaction — by snapshot ref (preferred for AI agents)
browserctl fill  login --ref e1 --value user@example.com
browserctl click login --ref e2

# Observation
browserctl snapshot login                   # interactable elements JSON (use this first for unknown layouts)
browserctl snapshot login --diff            # only elements changed since last snap
browserctl snapshot login --format html     # raw HTML
browserctl screenshot login                 # screenshot → /tmp/
browserctl screenshot login --out /tmp/my.png --full
browserctl evaluate  login "document.title" # evaluate a JS expression

# Waiting
browserctl wait login "button#submit"            # poll until selector appears
browserctl wait login ".toast" --timeout 5       # fail after 5s

# Recording
browserctl record start my_flow              # start capturing commands
browserctl record stop                       # end capture + auto-save to .browserctl/workflows/
browserctl record stop --out /tmp/my.rb      # or save to a custom path
browserctl record status                     # check if a recording is active

# Keyboard and mouse
browserctl press  main Enter                             # fire keydown+keyup (Enter, Tab, Escape, ArrowDown, ...)
browserctl hover  main "#menu-trigger"                  # move mouse to element centre
browserctl select main "select#country" "AU"            # set <select> value + fire change event
browserctl upload main "#resume-input" /path/file.pdf   # set file input to a local file

# Dialogs — register handler BEFORE the action that triggers the dialog
browserctl dialog accept  main                          # accept the next alert/confirm/prompt
browserctl dialog accept  main "my answer"              # accept + supply prompt text
browserctl dialog dismiss main                          # dismiss the next confirm

# HITL — ask human for a value inline (no browser pause needed)
browserctl ask "Enter 2FA code:"                        # prints prompt to stderr, returns JSON {ok, value}

# Human-in-the-loop (HITL)
browserctl pause  login                    # pause automation — browser stays live for manual interaction
browserctl pause  login --message "Solve the CAPTCHA, then: browserctl resume login"
browserctl resume login                    # resume automation after human action

# DevTools
browserctl devtools login          # open Chrome DevTools URL for a named page

# Cookies
browserctl cookie list   login                                                  # list all cookies as JSON
browserctl cookie set    login cf_clearance "xyz..." --domain ".example.com"   # set a cookie
browserctl cookie delete login                                                  # clear all cookies
browserctl cookie export login .browserctl/sessions/app.json                   # export to file
browserctl cookie import login .browserctl/sessions/app.json                   # import from file

# Storage (localStorage / sessionStorage)
browserctl storage get    login cart_id                                         # read a key (default: localStorage)
browserctl storage get    login cart_id --store session                         # read from sessionStorage
browserctl storage set    login cart_id "abc123"                                # write a key
browserctl storage export login .browserctl/storage.json                        # export all stores to file
browserctl storage export login .browserctl/storage.json --store local          # export localStorage only
browserctl storage import login .browserctl/storage.json                        # import storage from file
browserctl storage delete login                                                  # clear all storage
browserctl storage delete login --store session                                  # clear sessionStorage only

# Session (save/restore full browser state: pages + cookies + localStorage)
browserctl session save   myapp                          # snapshot current state (plaintext, 0o600)
browserctl session save   myapp --encrypt                # AES-256-GCM at rest, key in macOS Keychain
browserctl session load   myapp                          # restore into running daemon
browserctl session list                                  # list saved sessions
browserctl session delete myapp                          # delete a saved session
browserctl session export myapp /tmp/myapp.zip           # zip to portable archive
browserctl session export myapp /tmp/myapp.zip --encrypt # passphrase-protected zip (PBKDF2+AES-256-GCM)
browserctl session import /tmp/myapp.zip                 # unzip; detects and decrypts automatically

# Page management
browserctl page list
browserctl page close login
browserctl page focus login    # bring tab to front (headed mode only)

# Daemon
browserctl daemon ping    # → { ok: true, pid: N, protocol_version: "2" }
browserctl daemon status  # → { daemon: "online", pid: N, pages: [{name:, url:}] }
browserctl daemon start [--headed] [--name NAME]
browserctl daemon stop
browserctl daemon list    # list all running daemon instances

# Named daemon (multi-agent isolation)
browserd --name session-abc &
browserctl --daemon session-abc page open main --url https://app.example.com
```

## `browserd` flags

| Flag | Default | Description |
|---|---|---|
| `--headed` | headless | Start with a visible browser window |
| `--name <id>` | auto | Name this daemon instance; if omitted and the default slot is taken, auto-picks `d1`, `d2`, ... |
| `--log-level <level>` | `info` | Log verbosity: `debug`, `info`, `warn`, `error` |

## Snapshot format (elements)

`snapshot` (default) returns a JSON array of interactable elements:

```json
[
  { "ref": "e1", "tag": "input", "selector": "form > input", "attrs": { "name": "email", "placeholder": "Email" } },
  { "ref": "e2", "tag": "button", "text": "Sign in", "selector": "form > button" }
]
```

Use `ref` values directly with `--ref` for zero-fragility interactions — no selector knowledge required:

```sh
browserctl fill  login --ref e1 --value user@example.com
browserctl click login --ref e2
```

Or use `selector` values with `fill` and `click`. Prefer `snapshot` over raw HTML for token efficiency.

After the first `snapshot`, use `--diff` to fetch only what changed — avoids re-processing the full DOM on every step:

```sh
browserctl snapshot login --diff
```

## Naming pages

Use names that describe purpose:

| Good           | Bad  |
|----------------|------|
| `login`        | `p1` |
| `checkout`     | `tab2` |
| `admin-users`  | `page` |

## Probe before you write a workflow

Before writing a permanent workflow file, verify the flow works using discrete commands or a
throwaway script. Only harden once the sequence is confirmed reliable.

**Step 1 — Explore with discrete commands**

```sh
browserd --headed &
browserctl page open main --url https://app.example.com/login
browserctl snapshot main                      # learn the selectors
browserctl fill main "input[name=email]" me@example.com
browserctl fill main "input[name=password]" secret
browserctl click main "button[type=submit]"
browserctl url  main                          # confirm redirect
```

**Step 2 — Run a throwaway script to test the full flow**

Write a minimal `.rb` file anywhere and run it by path — no search-path setup needed:

```ruby
# /tmp/probe_login.rb
Browserctl.workflow "probe_login" do
  step "open" do
    open_page(:main, url: "https://app.example.com/login")
  end
  step "login" do
    page(:main).fill("input[name=email]", "me@example.com")
    page(:main).fill("input[name=password]", "secret")
    page(:main).click("button[type=submit]")
  end
  step "verify" do
    page(:main).wait("[data-test=dashboard]", timeout: 10)
    assert page(:main).url.include?("/dashboard")
  end
end
```

```sh
browserctl workflow run /tmp/probe_login.rb
```

**Step 3 — Harden into a named workflow**

Once the probe passes, move it to `.browserctl/workflows/`, add params, and run by name:

```ruby
# .browserctl/workflows/smoke_login.rb
Browserctl.workflow "smoke_login" do
  desc "Log in and verify dashboard redirect"
  param :email,    required: true
  param :password, secret_ref: "keychain://MyApp/password"   # resolves from OS keychain at runtime
  param :base_url, default: "https://app.example.com"

  step "open page" do
    open_page(:login, url: "#{base_url}/login")
  end

  step "fill form" do
    page(:login).fill("input[name=email]", email)
    page(:login).fill("input[name=password]", password)
    page(:login).click("button[type=submit]")
  end

  step "verify" do
    page(:login).wait("[data-test=dashboard]")
    assert page(:login).url.include?("/dashboard")
  end
end
```

```sh
browserctl workflow run smoke_login --email me@example.com --password secret
```

List available: `browserctl workflow list`
Describe one:   `browserctl workflow describe smoke_login`

Workflows in `./.browserctl/workflows/` are project-local.
Workflows in `~/.browserctl/workflows/` are global.

## Cloudflare challenges and HITL

`navigate` and `snapshot` responses include `challenge: true` when Cloudflare is detected. Use `pause` to hand control to a human, then poll until cleared:

```sh
# 1. Navigate — check for challenge
browserctl navigate main https://protected.example.com
# → { "challenge": true }

# 2. Pause and wait for human to solve
browserctl pause main
# (human solves challenge in browser window)
browserctl resume main

# 3. Capture cf_clearance for future sessions
browserctl cookie list main | jq '.cookies[] | select(.name == "cf_clearance")'
# → { "name": "cf_clearance", "value": "xyz...", "domain": ".example.com", "path": "/" }

# 4. Restore in a new session (skips re-solving)
browserctl page open main
browserctl cookie set main cf_clearance "xyz..." --domain ".example.com"
browserctl navigate main https://protected.example.com
```

> `cf_clearance` expires in 30 min–a few hours. Re-capture when Cloudflare challenges again.

## Rules

- **Probe before you harden** — explore with discrete commands or a throwaway file, then write the named workflow.
- **Prefer discrete commands** (`fill`, `click`, `press`, `select`, `hover`, `upload`) over `eval` for actions. Use `eval` only when no discrete command fits (e.g. reading computed DOM state, complex JS assertions).
- **Use `snapshot`** for any page you haven't seen before — the default `elements` format gives valid selectors and ref IDs without reading raw HTML.
- **Use `--ref` for interactions** — after a `snapshot`, prefer `--ref eN` over CSS selectors. Refs are valid until the next `snapshot` call — re-snapshot if you need fresh refs after page changes.
- **Use `snapshot --diff`** to detect DOM changes efficiently — avoids re-processing the full DOM after each action.
- **Use `wait`** when you need to wait for an element that appears asynchronously — more efficient than polling `snapshot`.
- **Use named daemons** (`browserd --name X`) when running multiple parallel sessions — each gets an isolated socket and browser.
- **Use descriptive page names.** Reuse the same name if the page is still open.
- **Log state at the end** of multi-step tasks: `browserctl url <page>` and `browserctl snapshot <page>`.
- **Use `press`** for keyboard shortcuts, form submission (`Enter`), navigation (`Tab`, `Escape`, `ArrowDown`). Prefer it over `evaluate` keyboard dispatch.
- **Use `dialog accept/dismiss` before the triggering action** — the handler is one-shot and fires when the dialog appears. Register it first, then click the button that triggers it.
- **Use `ask`** when automation needs a human-supplied value (2FA code, CAPTCHA answer, confirmation) but doesn't need to hand over full browser control. Cleaner than `pause` for value injection.
- **Use `pause`/`resume`** when a human must act mid-automation (e.g. solving a CAPTCHA, MFA). Poll `snap` after resume to confirm the blocker is cleared.
- **Capture `cf_clearance` after solving** a Cloudflare challenge — store and replay it with `cookie set` to avoid re-solving in future sessions.
- **Use `session save/load`** to persist the full browser state across daemon restarts — saves cookies, localStorage, and open page URLs. Load it on a fresh daemon to skip login entirely.
- **Use `secret_ref:` for credentials** — `param :password, secret_ref: "op://vault/item/field"` resolves the value from your keychain or secret manager at runtime. Never pass credentials as CLI flags or hardcode them in workflow files. `secret_ref:` always implies `secret: true`.
- **Use `load_session` with `fallback:`** instead of hand-rolling expiry detection — `load_session("myapp", fallback: "login_myapp")` handles the detect-expiry → re-login → retry cycle automatically.
- **Save stable sequences as workflows** — ask the user first, then write the `.rb` file. Use `browserctl record` to capture a live session automatically.

## Recording and refs

`browserctl record start <name>` captures a live session. Selector-based interactions replay perfectly. Ref-based interactions (`--ref eN`) cannot replay by ref — they are captured as commented-out TODO stubs in the generated workflow:

```ruby
# TODO: ref-based fill on "login" (ref: e1) — replace with a stable CSS selector
# step "..." do
#   page(:login).fill("YOUR_SELECTOR_HERE", ...)
# end
```

`record stop` prints a warning if any were found. Fix them by replacing the selector with the value from the snapshot JSON for that ref.

## Workflow DSL — page lifecycle

Use `open_page` and `close_page` for page lifecycle inside steps — do not call `client` directly:

```ruby
step "open tabs" do
  open_page(:login, url: "https://app.example.com/login")
  open_page(:inbox)                                        # open without navigating
end

step "close when done" do
  close_page(:login)
end
```

`page(:name)` — returns a `PageProxy` for commands on an already-open page.
`wait(selector, timeout: 30)` — poll until selector appears in the DOM; raises on timeout.

## Workflow DSL — full reference

| Method | Description |
|---|---|
| `desc "text"` | Human-readable description shown by `workflow list` |
| `param :name, required:, secret:, default:` | Declare an input parameter; `secret: true` masks the value from recordings |
| `param :name, secret_ref: "scheme://ref"` | Resolve the param's value from an external secret manager at runtime; implies `secret: true`. Built-in schemes: `env://VAR`, `keychain://service/account` (macOS), `op://vault/item/field` (1Password CLI). Third-party resolvers registered in `~/.browserctl/resolvers.rb`. |
| `step "label" { }` | Add a step — runs in order, halts workflow on failure |
| `step "label", retry_count: N { }` | Retry the step up to N additional times on any error |
| `step "label", timeout: S { }` | Fail the step if it exceeds S seconds |
| `step "label", retry_count: N, timeout: S { }` | Both retry and timeout |
| `compose "workflow"` | Inline all steps from another workflow at this point |
| `invoke "workflow", **overrides` | Call another workflow by name, optionally overriding params |
| `open_page(name, url: nil)` | Open a named page, optionally navigating to a URL |
| `close_page(name)` | Close a named page |
| `page(:name)` | Return a `PageProxy` for the named page |
| `save_session(name, encrypt: false)` | Snapshot current browser state to a named session; `encrypt: true` stores sensitive files as AES-256-GCM blobs with the key in macOS Keychain (darwin only) |
| `load_session(name)` | Restore a saved session into the running daemon |
| `load_session(name, fallback: "workflow_name")` | Restore session; if load fails, invoke the named fallback workflow then retry once. Use this instead of hand-rolling detect-expiry logic. |
| `list_sessions` | Return all saved session metadata |
| `store :key, value` | Store a value for use in later steps (persists in daemon until it stops) |
| `fetch :key` | Retrieve a value stored by an earlier step |
| `ask "prompt"` | Print prompt to stderr, read a line from stdin, return it as a string |
| `assert condition, "message"` | Raise `WorkflowError` if condition is false |

### `store` and `fetch`

Pass values between steps:

```ruby
step "read OTP" do
  code = page(:inbox).evaluate("document.querySelector('.otp-code')?.innerText?.trim()")
  store(:otp, code)
end

step "submit OTP" do
  page(:app).fill("input#otp", fetch(:otp))
  page(:app).click("button[type=submit]")
end
```

### `invoke`

Call another workflow by name, optionally overriding params. Circular invocation raises immediately:

```ruby
step "log in first" do
  invoke "smoke_login", email: admin_email, password: admin_password
end
```

### `compose`

Inline all steps from another workflow at the point of the call:

```ruby
Browserctl.workflow "full_flow" do
  compose "smoke_login"   # all steps from smoke_login inserted here
  step "continue" do
    page(:login).click(".next-button")
  end
end
```

### `ask` in workflow context

```ruby
step "enter 2FA" do
  code = ask("Enter the 2FA code:")
  page(:main).fill("#otp-input", code)
  page(:main).click("#verify")
end
```

### Step retry and timeout

```ruby
step "submit form", retry_count: 3 do
  page(:main).click("button[type=submit]")
end

step "wait for results", timeout: 10 do
  page(:main).wait(".results-list")
end

step "flaky call", retry_count: 2, timeout: 30 do
  page(:main).evaluate("fetch('/api/data').then(r => r.json())")
end
```

## PageProxy methods

Methods available on `page(:name)` inside a workflow (all raise `WorkflowError` on daemon error):

```ruby
page(:main).navigate(url)
page(:main).fill(selector, value)
page(:main).click(selector)
page(:main).press(key)                   # "Enter", "Tab", "Escape", "ArrowDown", ...
page(:main).hover(selector)              # move mouse to element centre
page(:main).upload(selector, path)       # set <input type="file"> to a local file
page(:main).select(selector, value)      # set <select> value + fire change event
page(:main).dialog_accept(text: nil)     # register one-shot: accept next alert/confirm/prompt
page(:main).dialog_dismiss               # register one-shot: dismiss next confirm
page(:main).wait(selector, timeout: 30)
page(:main).url
page(:main).evaluate(expression)
page(:main).snapshot(**opts)
page(:main).screenshot(**opts)
page(:main).storage_get(key, store: "local")
page(:main).storage_set(key, value, store: "local")
page(:main).delete_cookies
page(:main).devtools
```

## Troubleshooting

- `browserd is not running` → run `browserd &` or `browserctl daemon start`; check `~/.browserctl/browserd.log` for startup errors
- `default slot taken — starting as 'd1'` → connect with `browserctl --daemon d1 <command>`, or stop the existing daemon first
- `no page named 'X'` → run `browserctl daemon status` to see what's open, then `browserctl page open X`
- Selector not found → use `snapshot` to get valid selectors (elements format is the default)
- Stale page → `browserctl navigate <page> <url>` to reload
- Debug live → `tail -f ~/.browserctl/browserd.log`

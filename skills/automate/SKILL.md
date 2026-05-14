---
name: automate
description: Drive a persistent browser daemon with discrete shell commands — Chrome, Chromium, or Brave. Use for web automation, AI agent browser tasks, login flows, form filling, screenshots, and replayable Ruby workflows.
user-invocable: false
---

# browserctl — browser automation skill

## What this is

`browserctl` gives you a persistent browser you can control with discrete shell commands.
The browser state (open tabs, cookies, localStorage) survives between commands — you don't
restart the browser on every action. As of v0.9 the daemon is browser-agnostic: pick
Chrome (default), Chromium, or Brave with `-b/--browser`.

## Starting the daemon

```
browserd &                  # headless Chrome (default)
browserd --headed           # visible window
browserd -b brave           # use Brave instead of Chrome
browserd -b chromium -H     # Chromium, headed
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
browserctl page snapshot login                   # interactable elements JSON (use this first for unknown layouts)
browserctl page snapshot login --diff            # only elements changed since last snap
browserctl page snapshot login --format html     # raw HTML
browserctl page screenshot login                 # screenshot → ~/.browserctl/screenshots/
browserctl page screenshot login --out ~/.browserctl/screenshots/my.png --full
browserctl evaluate  login "document.title" # evaluate a JS expression

# Waiting
browserctl wait login "button#submit"            # poll until selector appears
browserctl wait login ".toast" --timeout 5       # fail after 5s

# Recording → workflow → flow (v0.11 replayable loop)
browserctl recording start my_flow            # start capturing commands
browserctl recording stop                     # end capture; recording log at ~/.browserctl/recordings/<name>.jsonl
browserctl recording status                   # check if a recording is active
browserctl workflow generate my_flow         # → .browserctl/workflows/my_flow.rb
browserctl workflow run my_flow --check      # replay + snapshot diff (run until 3× clean)
browserctl workflow promote my_flow          # → ~/.browserctl/workflows/my_flow.rb (gated by clean streak)
browserctl workflow promote my_flow --as-flow  # also writes ~/.browserctl/flows/my_flow.rb (callable as a flow)

# Keyboard and mouse
browserctl press  main Enter                             # fire keydown+keyup (Enter, Tab, Escape, ArrowDown, ...)
browserctl hover  main "#menu-trigger"                  # move mouse to element centre
browserctl hover  main --ref e3                          # move mouse to ref element
browserctl select main "select#country" "AU"            # set <select> value + fire change event
browserctl select main --ref e4 "AU"                    # set <select> by ref
browserctl upload main "#resume-input" /path/file.pdf   # set file input to a local file
browserctl upload main --ref e5 /path/file.pdf          # set file input by ref

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

# Flows (v0.10) — small, replayable auth surfaces. Prefer over hand-coded login.
browserctl flow list                                              # list registered flows (stdlib + project)
browserctl flow describe github_login                             # show params, preconditions, steps
browserctl flow run github_login --page work --username pat       # run against a named page; secret_ref params resolve at runtime

# State (v0.10) — single verb for "log in once, reuse later". Replaces session/cookie/storage as the recommended path.
browserctl state save   github --flow github_login                # snapshot cookies+storage, bind producing flow into the manifest
browserctl state save   github --encrypt                          # passphrase-protected at rest (AES-256-GCM)
browserctl state save   github --origins github.com,api.github.com # override auto-detected nav-chain origins
browserctl state load   github                                    # restore into running daemon; auto-rotates if AUTH_REQUIRED
browserctl state list                                             # show all bundles + origin/flow/age
browserctl state info   github                                    # manifest: origins, flow, flow_version, expiry hint
browserctl state rotate github                                    # invoke the bound flow + re-save (manual refresh)
browserctl state delete github
browserctl state export github ~/.browserctl/exports/github.bctl  # file path
browserctl state export github s3://bucket/key.bctl               # via aws CLI
browserctl state export github op://Vault/github-state            # via 1Password CLI
browserctl state import ~/.browserctl/exports/github.bctl

# Data (v0.15+) — unified verb for cookies / localStorage / sessionStorage.
#   The `--scope` flag is required; `cookie *` and `storage *` aliases were removed in v0.16.
#   Low-level escape hatch — prefer `state` for auth.
browserctl data list   login --scope cookies                                                  # list all cookies as JSON
browserctl data set    login cf_clearance "xyz..." --scope cookies --domain ".example.com"   # set a cookie (--domain required for cookies)
browserctl data delete login --scope cookies                                                  # clear all cookies

browserctl data get    login cart_id --scope localStorage                                     # read a localStorage key
browserctl data get    login cart_id --scope sessionStorage                                   # read a sessionStorage key
browserctl data set    login cart_id "abc123" --scope localStorage                            # write a localStorage key
browserctl data list   login --scope localStorage                                             # list all localStorage entries
browserctl data delete login --scope localStorage                                             # clear localStorage
browserctl data delete login --scope sessionStorage                                           # clear sessionStorage

# Page management
browserctl page list
browserctl page close login
browserctl page focus login    # bring tab to front (headed mode only)

# Daemon
browserctl daemon ping    # → { ok: true, pid: N, protocol_version: "2" }
                          #   or { ok: false, daemon: "offline", error: "..." } if not running
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
| `-H`, `--headed` | headless | Start with a visible browser window |
| `-b`, `--browser <name>` | `chrome` | Which browser to launch: `chrome`, `chromium`, or `brave` |
| `-n`, `--name <id>` | auto | Name this daemon instance; if omitted and the default slot is taken, auto-picks `d1`, `d2`, ... |
| `-l`, `--log-level <level>` | `info` | Log verbosity: `debug`, `info`, `warn`, `error` |

Browser binary discovery is automatic on macOS, Linux, and Windows. To override the resolved path, set one of: `CHROME_PATH`, `CHROMIUM_PATH`, `BRAVE_PATH`. If a browser isn't installed, `browserd` exits with a clear error pointing to the env var.

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
browserctl page snapshot login --diff
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
browserctl page snapshot main                 # learn the selectors
browserctl fill main "input[name=email]" me@example.com
browserctl fill main "input[name=password]" secret
browserctl click main "button[type=submit]"
browserctl url  main                          # confirm redirect
```

**Step 2 — Run a throwaway script to test the full flow**

Write a minimal `.rb` file anywhere and run it by path — no search-path setup needed:

```ruby
# ./probe_login.rb
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
browserctl workflow run ./probe_login.rb
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
browserctl data list main --scope cookies | jq '.cookies[] | select(.name == "cf_clearance")'
# → { "name": "cf_clearance", "value": "xyz...", "domain": ".example.com", "path": "/" }

# 4. Restore in a new session (skips re-solving)
browserctl page open main
browserctl data set main cf_clearance "xyz..." --scope cookies --domain ".example.com"
browserctl navigate main https://protected.example.com
```

> `cf_clearance` expires in 30 min–a few hours. Re-capture when Cloudflare challenges again.

> Switching browsers (Brave, Chromium) does **not** bypass Cloudflare Turnstile. The CDP attach itself is detected as automation regardless of the Chromium flavour. The reliable path is HITL solve once → capture `cf_clearance` → replay.

## Flows and state — the auth recovery loop (v0.10)

If a task needs an authenticated browser, **use a flow + state bundle** instead of hand-coding login steps. A flow is a small, replayable sequence that produces an authenticated state; a state bundle (`.bctl`) is the saved cookies+storage with a manifest binding it to its producing flow.

The recovery loop the daemon runs for you:

```
load_state → cookies still valid? ─yes→ continue
                       │
                       no
                       ▼
            run bound flow (from manifest) → save fresh bundle → continue
```

`load_state` returns `{rotated: true}` when this happened. No caller-side detect-expiry logic required.

The CLI surfaces the same loop via **exit code 7** = `AUTH_REQUIRED`. When you see exit 7 from any command, the JSON response carries `{code: "AUTH_REQUIRED", state: "<name>", suggested_flow: "<name>"}` — run that flow, retry the original command.

### Example 1 — Workflow with auto-rotate (preferred path)

```ruby
# .browserctl/workflows/check_inbox.rb
Browserctl.workflow "check_inbox" do
  step "load auth" do
    open_page(:work, url: "https://github.com")
    load_state(:github)              # transparently rotates if expired
  end
  step "do work" do
    page(:work).navigate("https://github.com/notifications")
    page(:work).wait("[data-testid=notifications-list]")
  end
end
```

First run: `browserctl flow run github_login --username pat --state-name github` to produce the bundle. After that, `workflow run check_inbox` re-authenticates automatically when cookies expire. No `fallback:` parameter needed — the manifest carries the binding.

### Example 2 — CLI loop with exit code 7

```sh
#!/usr/bin/env bash
set -e
attempt() { browserctl state load github && browserctl navigate work https://github.com/notifications; }
if ! attempt; then
  if [ "$?" -eq 7 ]; then
    browserctl flow run github_login --state-name github   # bundle is refreshed
    attempt
  else
    exit $?
  fi
fi
```

Use this shape when driving browserctl from a shell script or CI job.

### Example 3 — Explicit override with `on_auth_required`

```ruby
Browserctl.workflow "check_dashboard" do
  step "load auth" do
    open_page(:app, url: "https://app.example.com")
    load_state(:app, on_auth_required: -> {
      # Replace the default "invoke the bound flow" path — e.g. for a custom
      # 2FA prompt, ad-hoc HITL pause, or branching across SSO providers.
      ask("MFA code: ").tap { |code| invoke "company_sso_login", mfa: code }
    })
  end
  step "do work" do
    page(:app).wait("[data-test=dashboard]")
  end
end
```

Use when the default "invoke the bound flow" doesn't fit — the lambda runs in place of the flow, then the daemon re-saves the bundle.

## Rules

- **Probe before you harden** — explore with discrete commands or a throwaway file, then write the named workflow.
- **Prefer discrete commands** (`fill`, `click`, `press`, `select`, `hover`, `upload`) over `eval` for actions. Use `eval` only when no discrete command fits (e.g. reading computed DOM state, complex JS assertions).
- **Use `snapshot`** for any page you haven't seen before — the default `elements` format gives valid selectors and ref IDs without reading raw HTML.
- **Use `--ref` for interactions** — after a `snapshot`, prefer `--ref eN` over CSS selectors for `fill`, `click`, `hover`, `select`, and `upload`. Refs are valid until the next `snapshot` call — re-snapshot if you need fresh refs after page changes.
- **Use `snapshot --diff`** to detect DOM changes efficiently — avoids re-processing the full DOM after each action.
- **Use `wait`** when you need to wait for an element that appears asynchronously — more efficient than polling `snapshot`.
- **Use named daemons** (`browserd --name X`) when running multiple parallel sessions — each gets an isolated socket and browser.
- **Use descriptive page names.** Reuse the same name if the page is still open.
- **Log state at the end** of multi-step tasks: `browserctl url <page>` and `browserctl page snapshot <page>`.
- **Use `press`** for keyboard shortcuts, form submission (`Enter`), navigation (`Tab`, `Escape`, `ArrowDown`). Prefer it over `evaluate` keyboard dispatch.
- **Use `dialog accept/dismiss` before the triggering action** — the handler is one-shot and fires when the dialog appears. Register it first, then click the button that triggers it.
- **Use `ask`** when automation needs a human-supplied value (2FA code, CAPTCHA answer, confirmation) but doesn't need to hand over full browser control. Cleaner than `pause` for value injection.
- **Use `pause`/`resume`** when a human must act mid-automation (e.g. solving a CAPTCHA, MFA). Poll `snap` after resume to confirm the blocker is cleared.
- **Capture `cf_clearance` after solving** a Cloudflare challenge — store and replay it with `data set ... --scope cookies` to avoid re-solving in future sessions.
- **Use `flow run` over hand-coded login** (v0.10) — for any auth-gated task, prefer a registered flow (`browserctl flow list` to see what's available; `flow describe <name>` for params). Stdlib ships `totp_2fa`, `basic_auth`, `magic_link_email`, `oauth_google`, `oauth_github`, `cloudflare_solve`.
- **Use `state save/load` to persist auth across runs** (v0.10) — `state save <name> --flow <flow>` snapshots cookies+storage to `~/.browserctl/state/<name>.bctl` and binds the producing flow into the manifest; `state load <name>` restores and auto-rotates via the bound flow when cookies expired. Replaces ad-hoc cookie/storage juggling for auth.
- **Exit code 7 means re-auth** — any CLI command exiting 7 returned `AUTH_REQUIRED` with a `suggested_flow`. Run that flow, retry the command. From inside a workflow, `load_state` handles this loop transparently.
- **Use `secret_ref:` for credentials** — `param :password, secret_ref: "op://vault/item/field"` resolves the value from your keychain or secret manager at runtime. Never pass credentials as CLI flags or hardcode them in workflow files. `secret_ref:` always implies `secret: true`.
- **The `session` verb was removed in v0.13** — use `state save`/`state load` exclusively. The CLI no longer recognises `session` as a subcommand.
- **`load_session(fallback:, expired_if:)` is removed** — the recovery loop lives in `load_state`. Use `save_state(name, flow: :name)` + `load_state(name)`.
- **Save stable sequences as workflows** — ask the user first, then write the `.rb` file. Use `browserctl recording` to capture a live session automatically.

## Recording and refs

`browserctl recording start <name>` captures a live session. Selector-based interactions replay perfectly. Ref-based interactions (`--ref eN`) cannot replay by ref — they are captured as commented-out TODO stubs in the generated workflow:

```ruby
# TODO: ref-based fill on "login" (ref: e1) — replace with a stable CSS selector
# step "..." do
#   page(:login).fill("YOUR_SELECTOR_HERE", ...)
# end
```

`recording stop` prints a warning if any were found. Fix them by replacing the selector with the value from the snapshot JSON for that ref.

## The replayable loop (v0.11): explore → generate → check → promote

Once you have a recording, four CLI commands take you from a one-off exploration to a globally-invocable flow with no manual editing for the happy path:

```bash
# 1. Explore — drive the browser interactively while recording
browserctl recording start my_flow
# ... navigate / fill / click ...
browserctl recording stop

# 2. Generate — emit a Ruby workflow file
browserctl workflow generate my_flow
# → .browserctl/workflows/my_flow.rb
# Inferred: stable selectors, fingerprint comments, wait calls,
# url/snapshot postcondition asserts, secret_ref placeholders for
# password/token-shaped values.

# 3. Check — replay with snapshot-diff verification, three exit codes:
#    0 = :clean   every step passed, no drift
#    2 = :drift   passed via fingerprint rematch OR snapshot diff non-empty
#    1 = :fail    a step raised
browserctl workflow run my_flow --check

# 4. Promote — copy to ~/.browserctl/workflows/, optionally wrap as flow
browserctl workflow promote my_flow             # gated: 3 clean runs (default)
browserctl workflow promote my_flow --as-flow   # also write a flow wrapper
```

### How to react to `--check` output

Every `--check` run appends a verdict to `~/.browserctl/check_ledger.jsonl` and prints a JSON drift report. Read it before retrying:

```json
{ "drift": true, "rematches": 1, "unresolved": 0,
  "events": [{"command": "click", "selector": "form .old", "matched_ref": "ea11111", "score": 0.92, "reason": "rematch"}] }
```

- `:clean` → run again. After 3 consecutive `:clean` runs, you can promote.
- `:drift` with **rematches only** (high score, no unresolved) → the page shifted but the workflow still works. Either keep running until clean (the rematch is consistent and counts), or update the recorded selector to the rematched one if you want to lock it in. **Do not promote on a drift run** — the streak is reset.
- `:drift` with **unresolved events** → fingerprint matching couldn't find a candidate above threshold. The workflow is one mutation away from breaking. Re-record before promoting.
- `:fail` → a step raised. Read the error in the report, fix the selector or the step, re-check.

A fingerprint mismatch is data, not failure. Don't immediately re-record — read the drift report first.

### Fingerprints — what they are, how to reason about them

When the recorder logs a click or fill, it captures more than the CSS selector. Each interacted element ships a **fingerprint**: `{text, role, neighbors, position}`. At replay, if the recorded selector resolves cleanly, the fingerprint is ignored. If the selector misses, the matcher scores every candidate on the page against the fingerprint and picks the best one above threshold.

The drift report exposes the matcher's decision per event:

| Field | Meaning |
|-------|---------|
| `command` | The replay command that triggered fallback (`click`, `fill`, …). |
| `selector` | The selector from the recording that failed to resolve. |
| `matched_ref` | The ref the matcher chose (or `null` if `unresolved`). |
| `score` | Weighted similarity, `0.0`–`1.0`. Above ~`0.85` is high-confidence. |
| `reason` | `rematch` (matched above threshold), `no candidate above threshold`, or a structural reason. |

How to read it:

- **All events `rematch` with `score ≥ 0.85`** — the page changed cosmetically (renamed CSS class, refactored container). The workflow is fine. Continue running `--check`; once 3 clean runs land, promote. If you want to lock the new selector in, edit the recorded selector to match `matched_ref`'s current selector.
- **`rematch` with `0.6 ≤ score < 0.85`** — the matcher is uncertain. Visually verify in `--headed` mode that the right element was hit. If it was, lock the new selector in. If not, re-record.
- **`reason: "no candidate above threshold"`** — the original element is gone and nothing similar exists. The workflow needs a new step shape; re-record from `recording start`.
- **Many `rematch` events on a single run** — likely a structural redesign rather than drift. Re-record rather than rematching every step run after run.

The matcher's threshold defaults are conservative; a low-confidence rematch is more likely to be wrong than a high-confidence selector. When in doubt: re-record. When the report is consistent across runs: trust it.

### Promotion gates and overrides

The promotion gate is intentionally strict. Both `:drift` and `:fail` reset the clean streak. To override:

| Flag | When to use |
|------|-------------|
| `--threshold N` | Quick smoke (N=1) or extra strict (N=5+). |
| `--force` | You know the drift is benign and you want to ship. Use sparingly. |
| `--as-flow` | After promotion, generate a `Browserctl.flow` wrapper at `~/.browserctl/flows/<name>.rb` that runs the workflow via `Runner#run_workflow`. Params are inferred from the workflow's `param_defs`. The flow is registered globally and invocable as `browserctl flow run <name>`. |

Once promoted as a flow, the workflow remains the source of truth — edits to the workflow file flow through to the wrapper without regeneration.

### Secrets in generated workflows

The generator detects password / token / API-key shaped values and replaces them with `params[:secret_<field>]` plus a `param :secret_<field>, secret: true` declaration and a `# TODO: Configure a secret_ref:` header listing candidates. Before the first `--check`, edit the generated file to swap `secret: true` for the right resolver:

```ruby
param :secret_password, secret_ref: "op://Vault/Item/password"
param :secret_api_key,  secret_ref: "env://API_KEY"
param :secret_token,    secret_ref: "keychain://login/token"
```

This is the only manual edit the happy path requires.

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
| `compose "workflow"` | Inline all steps from another workflow at this point. Must be called at the workflow definition level — calling it inside a `step` block raises `WorkflowError`. Use `invoke` inside steps instead. |
| `invoke "workflow", **overrides` | Call another workflow by name, optionally overriding params |
| `open_page(name, url: nil)` | Open a named page, optionally navigating to a URL |
| `close_page(name)` | Close a named page |
| `page(:name)` | Return a `PageProxy` for the named page |
| `save_state(name, flow: :name, origins: nil, encrypt: false)` | (v0.10) Save cookies+storage as a `.bctl` bundle and bind the producing flow into the manifest so future `load_state` calls can auto-rotate. `origins:` overrides the auto-detected nav-chain origins. |
| `load_state(name)` | (v0.10) Restore a `.bctl` bundle. If the daemon detects AUTH_REQUIRED, it invokes the manifest's bound flow, re-saves, and continues. Returns `{rotated: true}` when this happened. |
| `load_state(name, on_auth_required: -> { ... })` | (v0.10) Same as above, but the lambda runs in place of the bound flow when AUTH_REQUIRED fires. Use for custom MFA prompts, branching SSO, or HITL pauses. |
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
page(:main).fill(selector = nil, value = nil, ref: nil)
page(:main).click(selector = nil, ref: nil)
page(:main).press(key)                                   # "Enter", "Tab", "Escape", "ArrowDown", ...
page(:main).hover(selector = nil, ref: nil)              # move mouse to element centre
page(:main).upload(selector = nil, path = nil, ref: nil) # set <input type="file"> to a local file
page(:main).select(selector = nil, value = nil, ref: nil) # set <select> value + fire change event
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
- `Brave browser not found` (or Chrome/Chromium) → install it, or set `BRAVE_PATH` / `CHROME_PATH` / `CHROMIUM_PATH` to the executable
- `default slot taken — starting as 'd1'` → connect with `browserctl --daemon d1 <command>`, or stop the existing daemon first
- `no page named 'X'` → run `browserctl daemon status` to see what's open, then `browserctl page open X`
- Selector not found → use `snapshot` to get valid selectors (elements format is the default)
- Stale page → `browserctl navigate <page> <url>` to reload
- Debug live → `tail -f ~/.browserctl/browserd.log`

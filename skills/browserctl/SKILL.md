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

Check it's alive: `browserctl ping`

## Core workflow

1. Open a named page (name describes purpose, e.g. `login`, `checkout`)
2. Navigate, fill, click using discrete commands
3. Use `snap` with `--format ai` when you don't know the layout
4. When a sequence stabilises, save it as a workflow

## Commands

```sh
# Navigation
browserctl open  login --url https://app.example.com/login
browserctl goto  login https://app.example.com/other
browserctl url   login

# Interaction
browserctl fill  login "input[name=email]"    user@example.com
browserctl fill  login "input[name=password]" secret
browserctl click login "button[type=submit]"

# Observation
browserctl snap login                   # AI-friendly DOM (use this first for unknown layouts)
browserctl snap login --format html     # raw HTML
browserctl shot login                   # screenshot → /tmp/
browserctl shot login --out /tmp/my.png --full

# Page management
browserctl pages
browserctl close login

# Daemon
browserctl ping
browserctl shutdown
```

## AI snapshot format

`snap --format ai` returns a JSON array of interactable elements:

```json
[
  { "ref": "e1", "tag": "input", "selector": "form > input", "attrs": { "name": "email", "placeholder": "Email" } },
  { "ref": "e2", "tag": "button", "text": "Sign in", "selector": "form > button" }
]
```

Use `selector` values directly in `fill` and `click`. Prefer `snap` over raw HTML for token efficiency.

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
browserctl open main --url https://app.example.com/login
browserctl snap main                          # learn the selectors
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
    page(:main).goto("https://app.example.com/login")
  end
  step "login" do
    page(:main).fill("input[name=email]", "me@example.com")
    page(:main).fill("input[name=password]", "secret")
    page(:main).click("button[type=submit]")
  end
  step "verify" do
    page(:main).wait_for("[data-test=dashboard]", timeout: 10)
    assert page(:main).url.include?("/dashboard")
  end
end
```

```sh
browserctl run /tmp/probe_login.rb
```

**Step 3 — Harden into a named workflow**

Once the probe passes, move it to `.browserctl/workflows/`, add params, and run by name:

```ruby
# .browserctl/workflows/smoke_login.rb
Browserctl.workflow "smoke_login" do
  desc "Log in and verify dashboard redirect"
  param :email,    required: true
  param :password, required: true, secret: true
  param :base_url, default: "https://app.example.com"

  step "open page" do
    page(:login).goto("#{base_url}/login")
  end

  step "fill form" do
    page(:login).fill("input[name=email]", email)
    page(:login).fill("input[name=password]", password)
    page(:login).click("button[type=submit]")
  end

  step "verify" do
    page(:login).wait_for("[data-test=dashboard]")
    assert page(:login).url.include?("/dashboard")
  end
end
```

```sh
browserctl run smoke_login --email me@example.com --password secret
```

List available: `browserctl workflows`
Describe one:   `browserctl describe smoke_login`

Workflows in `./.browserctl/workflows/` are project-local.
Workflows in `~/.browserctl/workflows/` are global.

## Rules

- **Probe before you harden** — explore with discrete commands or a throwaway file, then write the named workflow.
- **Prefer discrete commands** (`fill`, `click`) over `eval` for simple actions. Use `eval` when no discrete command fits (e.g. dropdowns, reading DOM state).
- **Use `snap --format ai`** for any page you haven't seen before — it gives valid selectors without reading raw HTML.
- **Use descriptive page names.** Reuse the same name if the page is still open.
- **Log state at the end** of multi-step tasks: `browserctl url <page>` and `browserctl snap <page>`.
- **Save stable sequences as workflows** — ask the user first, then write the `.rb` file.

## Troubleshooting

- `browserd is not running` → run `browserd &` first
- `no page named 'X'` → run `browserctl pages` to see what's open, then `browserctl open X`
- Selector not found → use `snap --format ai` to get valid selectors
- Stale page → `browserctl goto <page> <url>` to reload

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

## Workflows — reusable sequences

When a sequence of commands works reliably, save it as a workflow:

```ruby
# .browserctl/workflows/my_flow.rb
require_relative "path/to/lib/browserctl/workflow"

Browserctl.workflow "my_flow" do
  desc "What this does"
  param :email, required: true
  param :base_url, default: "https://app.example.com"

  step "open page" do
    page(:login).goto("#{base_url}/login")
  end

  step "fill form" do
    page(:login).fill("input[name=email]", email)
    page(:login).click("button[type=submit]")
  end

  step "verify" do
    page(:login).wait_for("[data-test=dashboard]")
    assert page(:login).url.include?("/dashboard")
  end
end
```

Run it: `browserctl run my_flow --email user@example.com`

List available: `browserctl workflows`
Describe one:   `browserctl describe my_flow`

Workflows in `./.browserctl/workflows/` are project-local.
Workflows in `~/.browserctl/workflows/` are global.

## Rules

- **Prefer discrete commands** (`fill`, `click`) over eval for simple actions.
- **Use `snap --format ai`** for any page you haven't seen before.
- **Use descriptive page names.** Reuse the same name if the page is still open.
- **Don't `eval` arbitrary JavaScript** unless a discrete command can't do it.
- **Log state at the end** of multi-step tasks: `browserctl url <page>` and `browserctl snap <page>`.
- **Save stable sequences as workflows** — ask the user first, then write the `.rb` file.

## Troubleshooting

- `browserd is not running` → run `browserd &` first
- `no page named 'X'` → run `browserctl pages` to see what's open, then `browserctl open X`
- Selector not found → use `snap --format ai` to get valid selectors
- Stale page → `browserctl goto <page> <url>` to reload

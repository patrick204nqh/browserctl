<p align="center">
  <img src=".github/logo.svg" width="96" height="96" alt="browserctl logo"/>
</p>

# browserctl

[![CI](https://github.com/patrick204nqh/browserctl/actions/workflows/ci.yml/badge.svg)](https://github.com/patrick204nqh/browserctl/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/browserctl.svg)](https://badge.fury.io/rb/browserctl)

A persistent browser automation daemon and CLI, purpose-built for AI agents and developer workflows.

Unlike tools that restart the browser on every script run, **browserctl keeps a named browser session alive** — preserving cookies, localStorage, open tabs, and page state across discrete commands.

```bash
browserd &                                          # start the daemon (headless)
browserctl open app --url https://example.com/login
browserctl fill app "input[name=email]" me@example.com
browserctl click app "button[type=submit]"
browserctl snap app                                 # AI-friendly JSON snapshot
browserctl shutdown
```

---

## Requirements

- Ruby >= 3.2
- Chrome or Chromium installed and on `PATH`

---

## Installation

```bash
gem install browserctl
```

Or in your `Gemfile`:

```ruby
gem "browserctl"
```

---

## Quick Start

**1. Start the daemon**

```bash
browserd           # headless (default)
browserd --headed  # visible browser window
```

**2. Open a named page**

```bash
browserctl open login --url https://app.example.com/login
```

**3. Interact with the page**

```bash
browserctl fill  login "input[name=email]"    user@example.com
browserctl fill  login "input[name=password]" s3cr3t
browserctl click login "button[type=submit]"
```

**4. Observe the result**

```bash
browserctl snap login              # AI-friendly JSON (default)
browserctl snap login --format html
browserctl shot login --out /tmp/after-login.png --full
browserctl url  login
```

**5. Manage pages and daemon**

```bash
browserctl pages
browserctl close login
browserctl ping
browserctl shutdown
```

---

## All Commands

### Browser commands _(require `browserd` running)_

| Command | Description |
|---|---|
| `open <page> [--url URL]` | Open or focus a named page |
| `close <page>` | Close a named page |
| `pages` | List open pages |
| `goto <page> <url>` | Navigate a page to a URL |
| `fill <page> <selector> <value>` | Fill an input field |
| `click <page> <selector>` | Click an element |
| `snap <page> [--format ai\|html]` | Snapshot DOM (default: ai) |
| `shot <page> [--out PATH] [--full]` | Take a screenshot |
| `url <page>` | Print current URL |
| `eval <page> <expression>` | Evaluate a JS expression |

### Daemon commands

| Command | Description |
|---|---|
| `ping` | Check if `browserd` is alive |
| `shutdown` | Stop `browserd` |

### Workflow commands

| Command | Description |
|---|---|
| `run <name> [--key value ...]` | Run a named workflow |
| `workflows` | List available workflows |
| `describe <name>` | Show workflow params and steps |

---

## AI Snapshot Format

`browserctl snap <page>` returns a compact JSON array of interactable elements — designed to be token-efficient for AI agents:

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
    "attrs": {
      "type": "submit"
    }
  }
]
```

Use `selector` values directly with `fill` and `click`.

---

## Workflows

Workflows are Ruby files using the `Browserctl.workflow` DSL. Place them in any of:

- `./.browserctl/workflows/`
- `./examples/`
- `~/.browserctl/workflows/`

### Example

```ruby
# examples/smoke_login.rb
Browserctl.workflow "smoke_login" do
  desc "Log in and confirm the dashboard loads"

  param :email,    required: true
  param :password, required: true, secret: true
  param :base_url, default: "https://app.example.com"

  step "open login page" do
    page(:login).goto("#{base_url}/login")
  end

  step "submit credentials" do
    page(:login).fill("input[name=email]",    email)
    page(:login).fill("input[name=password]", password)
    page(:login).click("button[type=submit]")
  end

  step "verify dashboard" do
    page(:login).wait_for("[data-test=dashboard]", timeout: 10)
    assert page(:login).url.include?("/dashboard")
  end
end
```

```bash
browserctl run smoke_login --email me@example.com --password s3cr3t
```

### Workflow DSL reference

| Method | Description |
|---|---|
| `desc "text"` | Human-readable description |
| `param :name, required:, secret:, default:` | Declare a parameter |
| `step "label" { }` | Add a step (runs in order, halts on failure) |
| `page(:name)` | Returns a `PageProxy` for the named page |
| `invoke "other_workflow", **overrides` | Call another workflow |
| `assert condition, "message"` | Raise `WorkflowError` if condition is false |

### PageProxy methods

`goto(url)` · `fill(selector, value)` · `click(selector)` · `snapshot(**opts)` · `screenshot(**opts)` · `wait_for(selector, timeout: 10)` · `url` · `evaluate(expression)`

---

## How it works

`browserd` runs as a background process, listening on a Unix socket at `~/.browserctl/browserd.sock`. It manages a Ferrum (Chrome DevTools Protocol) browser instance with named page handles.

`browserctl` sends JSON-RPC commands over the socket and prints the result. Workflows run in-process through the same client.

The daemon shuts itself down after 30 minutes of inactivity.

---

## Development

```bash
git clone https://github.com/patrick204nqh/browserctl
cd browserctl
bin/setup              # install deps + check for Chrome

bundle exec rspec      # run tests
bundle exec rubocop    # lint
```

---

## License

[MIT](LICENSE)

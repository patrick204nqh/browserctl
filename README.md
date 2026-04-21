<p align="center">
  <img src=".github/logo.svg" width="96" height="96" alt="browserctl logo"/>
</p>

# browserctl

[![CI](https://github.com/patrick204nqh/browserctl/actions/workflows/ci.yml/badge.svg)](https://github.com/patrick204nqh/browserctl/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/browserctl.svg)](https://badge.fury.io/rb/browserctl)
[![Downloads](https://img.shields.io/gem/dt/browserctl)](https://rubygems.org/gems/browserctl)

A persistent browser automation daemon and CLI, purpose-built for AI agents and developer workflows.

Unlike tools that restart the browser on every script run, **browserctl keeps a named browser session alive** — preserving cookies, localStorage, open tabs, and page state across discrete commands.

```bash
browserd &                                           # start the daemon (headless)
browserctl open login --url https://example.com/login
browserctl snap login                                # AI-friendly JSON snapshot with ref IDs
browserctl fill login --ref e1 --value me@example.com   # interact by ref
browserctl click login --ref e2
browserctl shutdown
```

![browserctl capturing a login flow](docs/screenshots/the_internet_login.png)
<p align="center"><sub>Login flow captured with <code>browserctl shot</code></sub></p>

---

## Why browserctl?

Most automation tools are stateless — every script spins up a fresh browser and tears it down. browserctl doesn't.

| | browserctl | Playwright / Selenium |
|---|---|---|
| Session persists across commands | ✓ | ✗ (per-script lifecycle) |
| Named page handles | ✓ | ✗ |
| AI-friendly DOM snapshot | ✓ | ✗ |
| Lightweight CLI interface | ✓ | ✗ |
| Full browser automation API | — | ✓ |
| Parallel multi-browser testing | — | ✓ |

**Use browserctl when** you need a browser that stays alive and remembers state — for AI agents, iterative dev workflows, or lightweight smoke tests.

**Use Playwright/Selenium when** you need parallel test suites, multi-browser support, or a full programmatic API.

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

## Claude Code Plugin

browserctl ships as a Claude Code plugin. Install it once and Claude automatically knows how to use the daemon, ref-based interaction, HITL patterns, and workflow authoring.

**Install (interactive)**

```
/plugin marketplace add patrick204nqh/browserctl
/plugin install browserctl@browserctl
```

**Install (project settings** — commit `.claude/settings.json` to share with your team)

```json
{
  "extraKnownMarketplaces": {
    "browserctl": {
      "source": { "source": "github", "repo": "patrick204nqh/browserctl" }
    }
  },
  "enabledPlugins": {
    "browserctl@browserctl": true
  }
}
```

Once installed, Claude Code loads the `browserctl` skill automatically — no `/invoke` needed.

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

**3. Snapshot the page to discover refs**

```bash
browserctl snap login              # AI-friendly JSON with ref IDs (default)
browserctl snap login --format html
```

**4. Interact using refs or selectors**

```bash
browserctl fill  login --ref e1 --value user@example.com
browserctl fill  login --ref e2 --value s3cr3t
browserctl click login --ref e3

# or using explicit CSS selectors
browserctl fill  login "input[name=email]"    user@example.com
browserctl click login "button[type=submit]"
```

**5. Observe the result**

```bash
browserctl snap login --diff       # only changed elements since last snap
browserctl shot login --out /tmp/after-login.png --full
browserctl url  login
```

**6. Manage pages and daemon**

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
| `set_cookie <page> <name> <value> <domain>` | Set a cookie (path defaults to `/`) |
| `clear_cookies <page>` | Clear all cookies for a page |
| `record start <name>` | Begin recording commands as a replayable workflow |
| `record stop [--out path]` | End recording; saves to `.browserctl/workflows/` or custom path |
| `record status` | Show whether a recording is active |

### Daemon commands

| Command | Description |
|---|---|
| `ping` | Check if `browserd` is alive |
| `shutdown` | Stop `browserd` |

### Workflow commands

| Command | Description |
|---|---|
| `run <name\|file.rb> [--key value ...]` | Run a named workflow or workflow file |
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

Use `ref` values directly with `--ref` for zero-fragility interactions, or use `selector` values with `fill` and `click`.

### Ref-based interaction

After a `snap`, use ref IDs instead of CSS selectors — no selector knowledge required:

```bash
browserctl fill  login --ref e1 --value user@example.com
browserctl click login --ref e2
```

### Diff snapshots

Track only what changed since the last snapshot — useful for AI agents monitoring async updates:

```bash
browserctl snap login --diff
```

---

## Workflows

Workflows are Ruby files using the `Browserctl.workflow` DSL. Place them in any of:

- `./.browserctl/workflows/`
- `~/.browserctl/workflows/`

### Example

```ruby
# .browserctl/workflows/smoke_login.rb
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
| `step "label", retry_count: N, timeout: S { }` | Step with retry and/or timeout |
| `page(:name)` | Returns a `PageProxy` for the named page |
| `invoke "other_workflow", **overrides` | Call another workflow |
| `assert condition, "message"` | Raise `WorkflowError` if condition is false |

### PageProxy methods

`goto(url)` · `fill(selector, value)` · `click(selector)` · `snapshot(**opts)` · `screenshot(**opts)` · `wait_for(selector, timeout: 10)` · `url` · `evaluate(expression)` · `pause` · `resume` · `inspect_page` · `cookies` · `set_cookie(name, value, domain, path: "/")` · `clear_cookies`

---

## Examples

Ready-to-run smoke tests against [the-internet.herokuapp.com](https://the-internet.herokuapp.com) are included in `examples/the_internet/`. See [docs/smoke-testing-the-internet.md](docs/smoke-testing-the-internet.md) for annotated output and auto-generated screenshots of each scenario.

For a full guide on building your own workflows, see [docs/writing-workflows.md](docs/writing-workflows.md).

---

## How it works

`browserd` runs as a background process, listening on a Unix socket at `~/.browserctl/browserd.sock`. Start multiple named instances for agent isolation:

```bash
browserd --name agent-a &
browserd --name agent-b &
browserctl --daemon agent-a open main --url https://app.example.com
```

It manages a Ferrum (Chrome DevTools Protocol) browser instance with named page handles.

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

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) · [SECURITY.md](SECURITY.md)

## License

[MIT](LICENSE)

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
browserd &                                               # start the daemon (headless)
browserctl open login --url https://example.com/login
browserctl snap login                                    # AI-friendly JSON snapshot with ref IDs
browserctl fill login --ref e1 --value me@example.com   # interact by ref, no selectors needed
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
| Human-in-the-loop pause/resume | ✓ | ✗ |
| Lightweight CLI interface | ✓ | ✗ |
| Full browser automation API | — | ✓ |
| Parallel multi-browser testing | — | ✓ |

**Use browserctl when** you need a browser that stays alive and remembers state — for AI agents, iterative dev workflows, or tasks that mix automation with human judgment.

**Use Playwright/Selenium when** you need parallel test suites, multi-browser support, or a full programmatic API.

---

## Requirements

- Ruby >= 3.3
- Chrome or Chromium on your `PATH`

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

```bash
# 1. Start the daemon
browserd &

# 2. Open a named page
browserctl open main --url https://the-internet.herokuapp.com/login

# 3. Snapshot the page — get AI-friendly JSON with ref IDs
browserctl snap main

# 4. Interact using refs
browserctl fill  main --ref e1 --value tomsmith
browserctl fill  main --ref e2 --value SuperSecretPassword!
browserctl click main --ref e3

# 5. Observe
browserctl url  main
browserctl snap main --diff   # only what changed

# 6. Done
browserctl shutdown
```

→ [Full Getting Started guide](docs/getting-started.md)

---

## How it works

`browserd` runs as a background process, listening on a Unix socket at `~/.browserctl/browserd.sock`. It manages a Ferrum (Chrome DevTools Protocol) browser instance with named page handles. `browserctl` sends JSON-RPC commands over the socket and prints the result.

Start multiple named instances for agent isolation:

```bash
browserd --name agent-a &
browserd --name agent-b &
browserctl --daemon agent-a open main --url https://app.example.com
```

The daemon shuts itself down after 30 minutes of inactivity.

---

## Documentation

| | |
|---|---|
| [Getting Started](docs/getting-started.md) | Install, first session, first snapshot |
| [Concepts](docs/concepts/) | Sessions, snapshots, human-in-the-loop |
| [Guides](docs/guides/) | Writing workflows, handling challenges, smoke testing |
| [Command Reference](docs/reference/commands.md) | Every command and flag |
| [vs. agent-browser](docs/vs-agent-browser.md) | How browserctl differs from Vercel's agent-browser |

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

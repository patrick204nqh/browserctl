# browserctl — Vision & Roadmap

> _Navigate the web. Stay in command._

---

## What browserctl Is

browserctl is a **persistent browser automation daemon and CLI**, purpose-built for AI agents and developer workflows. Unlike Selenium or Playwright, which restart the browser on every script run, browserctl keeps a named browser session alive — preserving cookies, localStorage, open tabs, and page state across discrete commands.

It is the difference between a browser **you restart** and a browser **you steer**.

---

## Brand

**Icon concept:** A sailboat helm — the circular steering wheel — rendered in sky blue (`#6CABDD`). The helm is both a navigator's instrument and a control surface, which maps directly to what the tool does: it gives you precise, persistent control over where the browser goes.

**Color palette:**
- Primary: `#6CABDD` — sky blue (open water, clear navigation)
- Dark: `#1C2E4A` — deep navy (focus, precision)
- Accent: `#FFFFFF` — clean white (minimal output, signal over noise)

**Voice:** Direct. Terse. The CLI output you read at a glance. No ceremony, no noise.

---

## Core Philosophy

1. **Persistence over restart** — the browser session is a first-class citizen, not a throwaway
2. **AI-first, human-compatible** — snapshots are token-efficient JSON; workflows are readable Ruby
3. **Unix composability** — every command is one-line, pipeable, scriptable
4. **Protocol over implementation** — the JSON-RPC wire format is stable and language-agnostic
5. **Zero magic, full control** — no auto-waiting policies you can't see; every operation is explicit

---

## Roadmap

### v0.2 — Stable Foundation _(pre-public release)_
**Goal:** Trustworthy enough to share privately. Fix the gaps before anyone depends on the API.

- [ ] README.md with install, quickstart, all commands
- [ ] Integration test suite (RSpec, real Chromium, headless)
- [ ] GitHub Actions CI (lint + test on push/PR)
- [ ] Thread-safe `@pages` access (Mutex on Server)
- [ ] Fix silent `click` failure — raise when selector not found
- [ ] Fix double `at_css` call in `fill` — capture node once
- [ ] Structured logging with severity levels (`--log-level`)
- [ ] Gemspec: add `changelog_uri`, `source_code_uri`, `bug_tracker_uri`
- [ ] CHANGELOG.md
- [ ] `.envrc` out of version control; document env var setup

### v0.3 — AI-First Enhancements
**Goal:** Make the AI integration story first-class.

- [ ] Ref-based interaction: `browserctl click login --ref e3` (use snapshot refs directly)
- [ ] `snap --diff` — returns only elements changed since last snapshot
- [ ] `watch` command — poll a selector and emit when it appears
- [ ] Multi-agent isolation: named daemon instances (`browserd --name session-abc`)
- [ ] Workflow `retry` and `timeout` options per step
- [ ] `record` command — capture a session as a replayable workflow
- [ ] Python and Node.js client SDKs (same JSON-RPC protocol)

### v0.4 — Developer Experience
**Goal:** The gem that developers actually recommend to each other.

- [ ] `browserctl init` — scaffold `.browserctl/` in a project
- [ ] Workflow composition: `include`, `extend`, shared step libraries
- [ ] Plugin system: `Browserctl.register_command(:my_cmd) { }` in workflow files
- [ ] RBS type signatures for all public API
- [ ] YARD documentation
- [ ] `browserctl inspect` — open DevTools UI for a named page

### v1.0 — Production-Ready
**Goal:** The tool you put in a Dockerfile without hesitation.

- [ ] Stable public API with deprecation policy
- [ ] Security audit (socket permissions, workflow param sanitization)
- [ ] Homebrew formula (`brew install browserctl`)
- [ ] RubyGems publish pipeline with signed gems
- [ ] Benchmarks: snapshot latency, command throughput
- [ ] Compatibility matrix: Ruby 3.2–3.x, Chrome 120+

### v1.x and Beyond — Platform
**Goal:** browserctl becomes the standard browser interface for agents.

- [ ] **Cloud daemon**: remote `browserd` instances accessible over mTLS
- [ ] **Session recording + replay**: deterministic browser regression testing
- [ ] **browserctl MCP server**: expose commands as MCP tools for Claude and other agents
- [ ] **Visual regression**: `shot --compare baseline.png` with pixel diff
- [ ] **Distributed sessions**: fan-out a command across N named pages in parallel
- [ ] **Webhook triggers**: run a workflow when an HTTP POST arrives
- [ ] **GUI companion app**: macOS status bar showing live page list and daemon health

---

## What browserctl Is Not

- Not a test framework (use Capybara for that)
- Not a scraping library (use Nokogiri/Mechanize for HTML-only work)
- Not a general-purpose RPA platform (no GUI recorder, no cloud SaaS)
- Not a replacement for Playwright in CI test suites

browserctl occupies the space between `curl` and Playwright: **interactive, stateful, composable browser control from the command line and from code**.

---

## The One-Line Pitch

> A persistent browser daemon with a Unix CLI and a Ruby DSL — built for AI agents that need to navigate the web without starting from scratch every time.

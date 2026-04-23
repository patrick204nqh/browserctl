# browserctl — Vision & Roadmap

> _Navigate the web. Stay in session._

---

## What browserctl Is

browserctl is a **persistent browser automation daemon and CLI**, purpose-built for AI agents and developer workflows. Unlike Selenium or Playwright, which restart the browser on every script run, browserctl keeps a named browser session alive — preserving cookies, localStorage, open tabs, and page state across discrete commands.

It is the difference between a browser **you restart** and a browser **you steer**.

---

## Brand

**Icon concept:** A galleon under full sail, set in a circular sky-blue badge. The ship reads as motion — persistent forward navigation — which maps directly to what the tool does: it keeps moving through the web without stopping to restart.

**Color palette:**
- Primary: `#6CABDD` — sky blue (open water, clear navigation)
- Dark: `#0D1B3E` — deep navy (focus, precision)
- Accent: `#FFFFFF` — clean white (sails, minimal output, signal over noise)

**Voice:** Direct. Terse. The CLI output you read at a glance. No ceremony, no noise.

---

## Core Philosophy

1. **Persistence over restart** — the browser session is a first-class citizen, not a throwaway
2. **AI-first, human-compatible** — snapshots are token-efficient JSON; workflows are readable Ruby
3. **Unix composability** — every command is one-line, pipeable, scriptable
4. **Protocol over implementation** — the JSON-RPC wire format is stable and language-agnostic
5. **Zero magic, full control** — no auto-waiting policies you can't see; every operation is explicit
6. **Human presence is a resumable event** — when the human needs to act, the session pauses and waits; when they're done, automation resumes exactly where it stopped
7. **Local-only, always** — the daemon runs on your machine; no cloud layer, no third-party access to your sessions, no SaaS dependency
8. **Detection before intervention** — built-in modules surface signals (Cloudflare challenges, bot-detection walls) so agents and workflows can decide when to invoke HITL; the detection layer is extensible, not hardcoded

---

## Roadmap

### v0.1.x — Stable Foundation ✓ _(shipped)_
**Goal:** Trustworthy enough to share publicly. Fix the gaps before anyone depends on the API.

- [x] README.md with install, quickstart, all commands
- [x] Integration test suite (RSpec, real Chromium, headless)
- [x] GitHub Actions CI (lint + test on push/PR)
- [x] Thread-safe `@pages` access (Mutex on Server)
- [x] Fix silent `click` failure — raise when selector not found
- [x] Fix double `at_css` call in `fill` — capture node once
- [x] Gemspec: add `changelog_uri`, `source_code_uri`, `bug_tracker_uri`
- [x] CHANGELOG.md
- [x] Release automation via release-please + RubyGems push
- [x] Structured logging with severity levels (`--log-level`)
- [x] `.envrc` out of version control; document env var setup

### v0.2 — AI-First Enhancements ✓ _(shipped)_
**Goal:** Make the AI integration story first-class.

- [x] Ref-based interaction: `browserctl click login --ref e3` (use snapshot refs directly)
- [x] `snap --diff` — returns only elements changed since last snapshot
- [x] `watch` command — poll a selector and emit when it appears
- [x] Multi-agent isolation: named daemon instances (`browserd --name session-abc`)
- [x] Workflow `retry_count:` and `timeout:` options per step
- [x] `record` command — capture a session as a replayable workflow

### v0.3 — Developer Experience ✓ _(shipped)_
**Goal:** The gem that developers actually recommend to each other.

- [x] `browserctl pause` / `browserctl resume` — human-in-the-loop pause/resume primitive
- [x] Cloudflare challenge detection in `snapshot` and `goto` responses (`challenge: true` field)
- [x] `browserctl init` — scaffold `.browserctl/` in a project
- [x] Workflow composition: `include`, `extend`, shared step libraries
- [x] Plugin system: `Browserctl.register_command(:my_cmd) { }` in workflow files
- [x] `browserctl inspect` — open DevTools UI for a named page
- [x] `browserctl cookies` / `set_cookie` / `clear_cookies` — read and restore browser cookies (e.g. `cf_clearance` replay after Cloudflare HITL)

### v0.4 — Installable Claude Plugin
**Goal:** The skill that any Claude Code user can install with one command.

- [x] `.claude-plugin/marketplace.json` — marketplace index so `/plugin marketplace add` works
- [x] `.claude-plugin/plugin.json` — plugin manifest declaring the skill
- [x] YAML frontmatter on `skills/browserctl/SKILL.md` — follow the Claude skill standard
- [x] Install instructions in README (`/plugin marketplace add` + `/plugin install`)
- [ ] RBS type signatures for all public API
- [ ] YARD documentation

### v1.0 — Production-Ready
**Goal:** The tool you put in a Dockerfile without hesitation.

- [ ] Stable public API with deprecation policy
- [ ] Security audit (socket permissions, workflow param sanitization)
- [ ] Homebrew formula (`brew install browserctl`)
- [ ] RubyGems publish pipeline with signed gems
- [ ] Benchmarks: snapshot latency, command throughput
- [ ] Compatibility matrix: Ruby 3.2–3.x, Chrome 120+

### v1.x and Beyond — Platform
**Goal:** browserctl becomes the runtime layer where human oversight produces better agents.

- [ ] **Annotated session traces**: export pause/resume sessions as fine-tuning data for browser agents
- [ ] **Extensible HITL detection modules**: a registry of built-in detectors (Cloudflare, DataDome, 2FA prompts, consent banners) that signal when human intervention is needed; third-party detectors installable via the plugin system
- [ ] **Session recording + replay**: deterministic browser regression testing
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
- Not a cloud browser service — the daemon runs on your machine, period

browserctl occupies the space between `curl` and Playwright: **interactive, stateful, composable browser control from the command line and from code**.

---

## The One-Line Pitch

> A persistent browser daemon with a Unix CLI and a Ruby DSL — built for AI agents that need to navigate the web without starting from scratch every time.

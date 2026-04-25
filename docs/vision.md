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
2. **Human presence is a resumable event** — when the human needs to act, the session pauses; when they're done, automation resumes exactly where it stopped
3. **Evidence by default** — every session can produce screenshots, traces, and recordings; capture is built in, not bolted on
4. **Local-only, always** — the daemon runs on your machine; no cloud layer, no third-party access to your sessions, no SaaS dependency, zero telemetry
5. **Detection before intervention** — built-in modules surface signals (Cloudflare challenges, bot-detection walls) so agents and workflows can decide when to invoke HITL; the detection layer is extensible, not hardcoded
6. **AI-first, human-compatible** — snapshots are token-efficient JSON; workflows are readable Ruby
7. **Unix composability** — every command is one-line, pipeable, scriptable
8. **Protocol over implementation** — the JSON-RPC wire format is stable and language-agnostic
9. **Zero magic, full control** — no auto-waiting policies you can't see; every operation is explicit

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
- [x] Workflow composition: `compose` — inline another workflow's steps
- [x] Plugin system: `Browserctl.register_command(:my_cmd) { }` in workflow files
- [x] `browserctl inspect` — open DevTools UI for a named page
- [x] `browserctl cookies` / `set_cookie` / `clear_cookies` / `export-cookies` / `import-cookies` — full cookie management including CF clearance replay

### v0.4 — Distribution & Installability _(current)_
**Goal:** Install with one command, anywhere.

- [x] `.claude-plugin/marketplace.json` — marketplace index so `/plugin marketplace add` works
- [x] `.claude-plugin/plugin.json` — plugin manifest declaring the skill
- [x] YAML frontmatter on `skills/browserctl/SKILL.md` — follow the Claude skill standard
- [x] Install instructions in README (`/plugin marketplace add` + `/plugin install`)
- [x] Homebrew formula — `brew install patrick204nqh/tap/browserctl`
- [x] CLI: rename `set_cookie` / `clear_cookies` → `set-cookie` / `clear-cookies` (hyphen rule)
- [x] `ping` response: add `protocol_version: "1"` as baseline for future negotiation
- [x] Split `pause_resume.rb` → `pause.rb` + `resume.rb` (one-command-per-file rule)

### v0.5 — Architecture & Protocol Lock
**Goal:** A codebase that contributors can navigate, a daemon that operators can trust, and a wire protocol that external tools can depend on. The Fixed zone is sealed at this milestone — no wire command names or response fields change without a major version bump after this point.

- [ ] API stability zones — `docs/reference/api-stability.md` sealing the Fixed zone contract _(drafted)_
- [ ] Style guide — `docs/reference/style-guide.md` codifying naming conventions per layer _(drafted)_
- [ ] RBS type signatures for all public API — documents the Stable zone contract
- [ ] YARD documentation — inline reference for SDK consumers
- [ ] `Browserctl::Error` hierarchy — typed error codes surfaced in daemon JSON responses
- [ ] Extract `Browserctl::Detectors` module — challenge detection isolated from dispatch logic
- [ ] Split `CommandDispatcher` into per-concern handler files
- [ ] Thread-safe plugin registry — replace mutable constants with mutex-protected accessors
- [ ] Promote `store` / `fetch` to wire protocol — currently WorkflowContext-only; must be Fixed before the lock
- [ ] Security audit: socket permissions, workflow param sanitisation, screenshot path boundaries
- [ ] Snapshot content boundaries — nonce-delimited `snap` output to prevent prompt injection from adversarial pages
- [ ] Domain/action policy support — `BROWSERCTL_ALLOWED_DOMAINS` env var (or config) to gate navigation to approved origins
- [ ] Compatibility matrix: Ruby 3.2–3.x, Chrome 120+
- [ ] Benchmarks: snapshot latency, command throughput

### v0.6 — Evidence & Reproduction
**Goal:** Every session leaves a trail. Every bug is reproducible from code.

- [ ] Evidence capture hooks — configurable auto-screenshot (on HITL pause, on step failure, per-step)
- [ ] Session trace export — structured JSON log of every command; `browserctl export main`
- [ ] `replay` command — step through a recorded workflow with live screenshots at each step
- [ ] Extensible HITL detection modules — DataDome, 2FA prompts, consent banners as built-in detectors
- [ ] `register_detector` plugin API — third-party detectors installable via plugin system

### v0.7 — Platform
**Goal:** browserctl becomes the runtime layer where human oversight produces better agents.

- [ ] Annotated session traces — export pause/resume sessions as fine-tuning data for browser agents
- [ ] Session recording + replay — deterministic browser regression testing
- [ ] Visual regression — `shot --compare baseline.png` with pixel diff
- [ ] Distributed sessions — fan-out a command across N named pages in parallel
- [ ] Webhook triggers — run a workflow when an HTTP POST arrives
- [ ] GUI companion app — macOS status bar showing live page list and daemon health

### v1.0 — Production-Ready
**Goal:** Ship it when it's ready. No checklist owns this milestone — it will be cut when the project is stable enough to warrant a compatibility promise and a deprecation policy.

What "ready" means: the Fixed and Stable zones carry an explicit compatibility promise — breaking them is a considered decision with a migration path, not an accident. The security audit is closed. The architecture has absorbed real usage feedback from agents and developers in the wild.

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

> The browser you delegate to your agents — with a pause button for the parts that still need you.

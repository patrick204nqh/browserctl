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
10. **Credentials stay yours** — secrets resolve from your keychain or secret manager at runtime; they are never written to recordings, session files, or logs

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

> _(All commands in this section were renamed in v0.6: `inspect` → `devtools`; `cookies`/`set_cookie`/`clear_cookies`/`export-cookies`/`import-cookies` → `cookie list`/`cookie set`/`cookie delete`/`cookie export`/`cookie import`.)_

### v0.4 — Distribution & Installability ✓ _(shipped)_
**Goal:** Install with one command, anywhere.

- [x] `.claude-plugin/marketplace.json` — marketplace index so `/plugin marketplace add` works
- [x] `.claude-plugin/plugin.json` — plugin manifest declaring the skill
- [x] YAML frontmatter on `skills/browserctl/SKILL.md` — follow the Claude skill standard
- [x] Install instructions in README (`/plugin marketplace add` + `/plugin install`)
- [x] Homebrew formula — `brew install patrick204nqh/tap/browserctl`
- [x] CLI: rename `set_cookie` / `clear_cookies` → `set-cookie` / `clear-cookies` (hyphen rule)
- [x] `ping` response: add `protocol_version: "1"` as baseline for future negotiation
- [x] Split `pause_resume.rb` → `pause.rb` + `resume.rb` (one-command-per-file rule)

### v0.5 — Architecture & Protocol Lock ✓ _(shipped)_
**Goal:** A codebase that contributors can navigate, a daemon that operators can trust, and a wire protocol that external tools can depend on. The Fixed zone is sealed — no wire command names or response fields change without a major version bump after this point.

- [x] API stability zones — `docs/reference/api-stability.md` sealing the Fixed zone contract
- [x] Style guide — `docs/reference/style-guide.md` codifying naming conventions per layer
- [x] RBS type signatures — `sig/browserctl.rbs` documents the Stable zone contract
- [x] `Browserctl::Error` hierarchy — typed error codes surfaced in daemon JSON responses
- [x] Extract `Browserctl::Detectors` module — challenge detection isolated from dispatch logic
- [x] Split server into per-concern handler files — `server/handlers/`
- [x] Thread-safe workflow registry — `@registry_mutex` on `Browserctl.workflow`
- [x] Promote `store` / `fetch` to wire protocol — `cmd_store` / `cmd_fetch` in daemon handlers
- [x] Domain/action policy support — `BROWSERCTL_ALLOWED_DOMAINS` env var via `policy.rb`
- [x] Cookie export/import commands
- [ ] YARD documentation — deferred
- [ ] Snapshot content boundaries — deferred
- [ ] Compatibility matrix (Ruby 3.3+ only for now) — deferred
- [ ] Benchmarks — deferred

### v0.6 — CLI Redesign & Storage ✓ _(shipped)_
**Goal:** A consistent noun-verb CLI surface with first-class web storage control.

- [x] Noun-verb command structure — `browserctl page open`, `browserctl state save` (the `state` verb was named `session` until v0.13), `browserctl workflow run`
- [x] `storage get/set/export/import/delete` — direct Web Storage access without custom scripts
- [x] Daemon auto-index — second unnamed daemon auto-picks next available slot
- [x] `page focus` command
- [x] Full integration spec suite

### v0.7 — Interaction Primitives ✓ _(shipped)_
**Goal:** Complete the interaction surface — every common browser action available from the DSL and CLI.

- [x] `press(key)` — keyboard event dispatch
- [x] `hover(selector)` — mouse movement
- [x] `upload(selector, path)` — file input control
- [x] `select(selector, value)` — `<select>` element control
- [x] `dialog_accept` / `dialog_dismiss` — alert, confirm, and prompt handling
- [x] `ask(prompt)` — read a value from the operator at runtime

### v0.8 — Credentials & Session Durability
**Goal:** Production-grade workflows without infrastructure boilerplate.

- [x] Secret resolver plugin system — `param :password, secret_ref: "op://vault/item/field"`
- [x] Built-in resolvers: `env://`, `keychain://` (macOS), `op://` (1Password CLI)
- [x] User-defined resolvers via `~/.browserctl/resolvers.rb`
- [x] `load_session` with `fallback:` — automatic session expiry recovery
- [x] Session encryption at rest — `browserctl state save --encrypt` (the `state` verb was named `session` until v0.13)
- [x] Export encryption — `browserctl session export --encrypt` with passphrase

### v0.8.3 — Session Durability (patch)
**Goal:** Close the remaining gap in the v0.8 session expiry recovery story.

- [x] `expired_if:` on `load_session` — detect server-side session expiry and auto-recover via fallback

### v0.9 — Browser-Agnostic Driver ✓ _(shipped)_
**Goal:** Decouple the daemon from a single browser. Same daemon, same protocol, multiple Chromium-family browsers.

- [x] Driver abstraction layer — CDP client interface separated from Ferrum specifics
- [x] Chrome / Chromium / Brave support via `-b/--browser` flag
- [x] Auto binary discovery with `CHROME_PATH`, `CHROMIUM_PATH`, `BRAVE_PATH` overrides
- [x] Skill split — `automate` (AI-driven) and `feedback` (user-invoked) as separate manifests

> **Strategic shift after v0.9.** Pre-1.0 development now optimises for two things: making AI-driven exploration produce durable workflows, and proving the HITL + reusable-flow model that no competitor has. **Breaking changes are acceptable** between minor versions until 1.0; deprecation policy starts at 1.0. Ruby support is **3.3 only** through the 0.x series to keep the CI matrix small. MCP server work is parked — skills remain the primary AI surface.

### v0.10 — Flows
**Goal:** Make browser auth and any other repeatable interaction a named, parameterised, secret-aware, composable artifact. The moat.

**Reusable Flow DSL**
- [ ] `Browserctl.flow :name do … end` — first-class flow definition with `version`, `desc`, `param`, `step`, `precondition`, `postcondition`, `produces_state`
- [ ] Flow registry — auto-load from `~/.browserctl/flows/` (user) and `./.browserctl/flows/` (project), project wins
- [ ] `invoke :flow_name` from inside any workflow or other flow
- [ ] CLI: `browserctl flow run/list/describe`
- [ ] Stdlib flows — `oauth_google`, `oauth_github`, `totp_2fa`, `magic_link_email`, `cloudflare_solve`, `basic_auth`

**Unified state command**
- [ ] `browserctl state save/load/list/info/delete/export/import/rotate`
- [ ] `.bctl` bundle format — manifest + cookies + localStorage + sessionStorage + (optional) IndexedDB, HMAC-signed, optionally encrypted
- [ ] Origin-scoped by default; full-browser scope opt-in
- [ ] Bundle metadata declares `expires_at`, source flow, flow version
- [ ] Three blessed transports for portability: file, S3-compatible, 1Password document
- [ ] Existing `cookie *` / `storage *` verbs retained as low-level escape hatches

**Auth re-detection**
- [ ] Daemon emits `auth_required` event when login redirects, 401/403, or expired cookies are detected
- [ ] CLI exit code `7` for auth-required; structured error payload with `suggested_flow`
- [ ] Workflow DSL: automatic re-run of bound flow on `load_state` expiry; explicit `on_auth_required` override
- [ ] Skill update — `automate` teaches the AI to react to `auth_required`

### v0.11 — Replayable
**Goal:** Turn ephemeral AI exploration into durable, version-controlled workflows.

**Stable refs and fingerprints**
- [x] Replace `snapshot` — refs derived from `(role, accessible-name, tag, parent-path)` hash; same element → same ref across snapshots (breaking change, no `_v2` suffix)
- [x] Fingerprint blob per element (text, ARIA role, neighbor signature, position) emitted alongside ref
- [x] Fingerprint-based fuzzy match on replay when selectors fail — Scrapling-style self-healing for recordings
- [x] Migration note in CHANGELOG — old recordings re-record, not auto-migrate

**Recording → workflow → flow pipeline**
- [x] `browserctl workflow generate <recording>` — emits a Ruby workflow with stable selectors, fingerprint fallbacks as comments, secret detection (`secret_ref:` placeholders), inferred waits, postconditions
- [x] `browserctl workflow run --check` — replay with snapshot-diff assertions; flag drift
- [x] `browserctl workflow promote <name>` — graduate to `~/.browserctl/workflows/`
- [x] `browserctl workflow promote --as-flow` — register a workflow as a reusable flow (closes the loop with v0.10)
- [x] Skill update — `automate` teaches the AI the explore → generate → check → promote loop

### v0.12 — Solid
**Goal:** Earn the right to call 1.0. Determinism, observability, performance budgets, real test pyramid.

**Determinism**
- [ ] Versioned formats for recordings, workflows, state bundles — explicit `version:` in every header (snapshot stays unversioned; refs are deterministic by construction)
- [ ] Migration helpers between format versions where needed
- [ ] No implicit waits; every wait is explicit and surfaced in errors

**Error model**
- [ ] Standardised error codes across daemon and CLI (e.g. `AUTH_REQUIRED`, `SELECTOR_NOT_FOUND`, `STATE_EXPIRED`)
- [ ] CLI exit codes mapped 1:1 to error categories
- [ ] Structured `{code, message, context, suggested_action}` payload everywhere

**Observability**
- [ ] JSONL structured logs in `~/.browserctl/logs/`
- [ ] `browserctl trace <session>` — pretty timeline of events, snapshots, network, errors
- [ ] Crash reports on daemon panic with last 50 events

**Test pyramid**
- [ ] Unit tests for snapshot/ref/fingerprint, secret resolver, bundle codec
- [ ] Integration tests for every CLI command, error path, and JSON-RPC contract
- [ ] Workflow replay matrix across Chrome / Chromium / Brave
- [ ] Smoke tests against stable public sites, run nightly

**Performance budgets (CI-enforced)**
- [ ] `snapshot` p95 < 250 ms on a typical page
- [ ] `click` ack < 50 ms (action dispatch)
- [ ] Daemon RSS < 200 MB idle
- [ ] State bundle < 50 KB typical

**Compatibility matrix**
- [ ] CI: Ruby 3.3 only (cost-saving choice through 0.x)
- [ ] CI: macOS 14+, Ubuntu 22+, Windows-via-WSL2
- [ ] Pinned Ferrum minor; explicit upgrade PRs only

### v1.0 — Production-Ready
**Goal:** A compatibility promise the project can keep.

Ship 1.0 when v0.12 has been crash-free for two months in real use, the Fixed and Stable zones in `docs/reference/api-stability.md` carry an explicit compatibility promise, the security review is closed, and the architecture has absorbed feedback from agents and developers in the wild.

After 1.0: deprecation policy kicks in — one minor of warning before any breaking change in the Stable zone; never break the Fixed zone without a major.

### Parked
- **MCP server.** Skills remain the primary AI surface. Revisit only if there is concrete demand from non-Claude clients (Cursor, Codex, Cline) that skills can't address.
- **Cloud / remote daemon mode.** Local-only is a core philosophy; remoting is an explicit non-goal pre-1.0.
- **Annotated screenshots with ref-overlay numbers.** Useful for vision agents but a smaller segment than the flow/replay work; revisit post-1.0.
- **Visual regression / pixel diff, distributed fan-out, webhook triggers, macOS GUI.** From the previous v0.10 plan — deferred behind the moat-building work.

---

## What browserctl Is Not

See [Product — What It Is Not](product.md#what-it-is-not).

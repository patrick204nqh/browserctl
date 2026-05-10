# AGENTS.md

Guidance for AI coding agents working in this repo. Follows the [agents.md](https://agents.md) convention.

## Project overview

`browserctl` is a Ruby gem and CLI for delegating browser automation to AI agents. A persistent daemon (`browserd`) keeps a browser session alive between commands so agents can pick up where they left off — no per-script re-authentication or re-navigation. Driven by Ferrum over CDP. Supports Chrome, Chromium, and Brave.

The gem is in active 0.x development. The next milestone is **v0.12** (see `docs/plans/v0.12-solid.md`); 1.0 is gated on a two-month soak after v0.12 ships.

## Setup

```bash
bin/setup            # install deps
bundle exec rspec    # run the test suite
bundle exec rubocop  # lint
```

The test suite includes integration specs that drive a real browser. Chromium must be installed locally; CI uses Ubuntu + Chromium only (Ruby 3.4).

## Repository layout

- `lib/browserctl/` — gem source. Public surface area is documented in `docs/reference/api-stability.md` (Fixed / Stable / Experimental zones).
- `exe/` — `browserctl` (CLI) and `browserd` (daemon) entry points.
- `spec/` — RSpec tests. Unit, integration, and replay-matrix specs.
- `bench/` — benchmark harness (`rake bench:all`); budgets in `bench/budgets.yml`.
- `docs/` — `reference/` (stable, user-facing), `guides/` (how-to), `plans/` (in-flight milestones), `adrs/` (decision records), `vision.md` (north star).
- `rakelib/` — Rake tasks for bench, smoke workflows, and demo asset generation.

## Code style

- **Ruby 3.3 floor** in the gemspec. **Do not lower this.** CI tests Ruby 3.4 only as a deliberate cost choice.
- RuboCop is authoritative. The custom cop `Browserctl/TypedError` enforces typed errors over stdlib raises — every raise must carry a code from `Browserctl::Error::Codes`.
- Prefer typed errors and structured payloads over prose. The error model (codes, exit-code map, JSON-RPC payload shape) is documented in `docs/reference/errors.md` and `docs/reference/exit-codes.md`.
- Persisted artifacts (bundles, recordings, workflows) all carry a `version:` header — see `docs/reference/format-versions.md`. Don't introduce new persisted formats without versioning.
- No emojis in code, commit messages, or PR bodies.

## Testing

- `bundle exec rspec` runs everything; integration specs require a working Chromium.
- Unit, integration, and workflow-replay layers are all expected to pass on a developer machine — no `pending` for browser-required cases.
- New error paths should be covered by table-driven integration tests generated from the error code enum.
- Benchmarks are not part of the default rspec run; use `rake bench:run[name]` or `rake bench:all`.

## Commits and PRs

- **Always branch + open a PR.** Never push directly to `main`, even for tiny fixes. The maintainer self-reviews.
- **Conventional Commits** for the subject line: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `ci:`, `chore:`. Used by release-please for changelog generation.
- **Do not add `Co-Authored-By` lines** to commits.
- **Do not add "Generated with Claude Code"** or any AI attribution to PR bodies, commit messages, or anything else project-facing.
- Breaking changes: add a `BREAKING CHANGE:` footer (release-please picks it up). For v0.x work that should not trigger a 1.0 bump, add `Release-As: 0.x.y` to override.

## Sub-agents and worktrees

If dispatching sub-agents inside a `git worktree`, brief them that Bash `cwd` does not persist between calls — otherwise they may end up editing the parent repo by accident. Course-correct in-flight sub-agents via `SendMessage`, not by spawning a fresh agent (the new one loses branch context).

## Security

- Secrets are resolved via `Browserctl::Secrets`; never log or persist resolved values.
- The `trace --redact` flag is the default-safe path for sharing session traces — assume traces are public unless explicitly told otherwise.
- Crash reports (`crash-<timestamp>.json`) are local-only. Do not add upload/telemetry without an opt-in flag and an ADR.

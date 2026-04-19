# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-19

### Added
- Persistent browser daemon (`browserd`) over Unix socket — preserves cookies, localStorage, and open tabs across discrete commands
- CLI (`browserctl`) with commands: `open`, `close`, `pages`, `goto`, `fill`, `click`, `shot`, `snap`, `url`, `eval`, `ping`, `shutdown`
- Ruby workflow DSL with `param`, `step`, `assert`, `page(:name)`, and `invoke` for composing workflows
- AI-optimized DOM snapshot format (`snap --format ai`) — compact JSON array of interactable elements with stable ref IDs
- Ferrum-backed Chrome/Chromium automation via Chrome DevTools Protocol
- Named page handles — multiple pages open simultaneously under descriptive names
- `wait_for(selector, timeout:)` — polls until an element appears, useful for async content
- Workflow search paths: `.browserctl/workflows/` (project) and `~/.browserctl/workflows/` (user)
- `browserctl run <name|file.rb>` — run workflows by name or directly by file path
- `browserctl workflows` and `browserctl describe <name>` — discover and inspect available workflows
- GitHub Actions CI: lint (RuboCop) and integration tests
- Gemspec metadata: `changelog_uri`, `source_code_uri`, `bug_tracker_uri`, `rubygems_mfa_required`
- Release automation via release-please and RubyGems push on `v*.*.*` tags
- AI agent skill (`skills/browserctl/SKILL.md`) with probe-before-workflow guidance
- Workflow authoring guide (`docs/writing-workflows.md`)
- Smoke test examples against the-internet.herokuapp.com with auto-generated screenshots

### Fixed
- Thread safety: all server dispatch calls protected by a Mutex
- `fill` returns an error when selector is not found instead of querying the DOM twice
- `click` returns an error when selector is not found instead of silently succeeding
- `wait_for` polls for the selector until timeout instead of checking once after network idle
- Circular workflow `invoke` calls raise a descriptive `WorkflowError`
- Chrome launch on CI: added `--no-sandbox` and `--disable-dev-shm-usage` flags for container environments
- Daemon shutdown no longer hangs: `browser.quit` is wrapped in a 5s timeout; `stop_daemon` sends `SIGKILL` as a fallback after grace period

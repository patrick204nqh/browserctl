# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0](https://github.com/patrick204nqh/browserctl/compare/v0.1.1...v0.2.0) (2026-04-20)


### Features

* add architecture documentation and decision records with diagrams ([9b67e40](https://github.com/patrick204nqh/browserctl/commit/9b67e40892cb87a075818fd7b166584a48c8edff))
* add logging functionality and environment variable setup documentation ([feb529c](https://github.com/patrick204nqh/browserctl/commit/feb529c4040c6f84104fa6dc55afc8d0a5d1b1a7))
* add record command — capture session as replayable workflow ([bb8988b](https://github.com/patrick204nqh/browserctl/commit/bb8988bcf17c0a7689f5a6e53d755d0e6a69b359))
* add ref registry and diff cache to CommandDispatcher ([217e158](https://github.com/patrick204nqh/browserctl/commit/217e15831b2cf1f0bf693584f47ed5d315594803))
* add ref-based click and fill using snapshot registry ([f0251c0](https://github.com/patrick204nqh/browserctl/commit/f0251c0732fd535bde8746b2817d3674ec8bc353))
* add retry_count and timeout options to workflow steps ([7b5e694](https://github.com/patrick204nqh/browserctl/commit/7b5e694cfb246396502a07b02928de79233a715f))
* add snap --diff returning only changed elements ([0a09558](https://github.com/patrick204nqh/browserctl/commit/0a095583ea23b1cff0df1ecc6cb91a3e35039e2c))
* add watch command — poll selector and emit when found ([b9a3abf](https://github.com/patrick204nqh/browserctl/commit/b9a3abf15b7e021906dda940f29f029ca3c221c2))
* named daemon instances via browserd --name and multi-socket support ([8cbc62d](https://github.com/patrick204nqh/browserctl/commit/8cbc62d6c8931b23cbf31e7285ee52c62e280f5c))
* v0.2 AI-first enhancements ([d3246d4](https://github.com/patrick204nqh/browserctl/commit/d3246d4c861430fda1e7dfa1cb67ce22db33dd68))


### Bug Fixes

* add edited event and workflow_dispatch to release trigger ([b851306](https://github.com/patrick204nqh/browserctl/commit/b85130603986ea5a667f2a89e9af7139c38491f2))
* add paths-ignore for markdown and docs in CI workflow ([3b7801d](https://github.com/patrick204nqh/browserctl/commit/3b7801dfa536ea0b0cd9bab189f237a2709e1515))
* describe_workflow after StepDef refactor; skip nil-selector recording for ref commands ([9e437fa](https://github.com/patrick204nqh/browserctl/commit/9e437fa9c18b6c94259a652af238377ce120d12e))
* fill --ref uses --value flag; add record generate subcommand ([ef3ed43](https://github.com/patrick204nqh/browserctl/commit/ef3ed433e09c0ae8ac6e241949ee9c2c0ccaa03c))
* remove 'edited' type from release trigger events ([98f63f0](https://github.com/patrick204nqh/browserctl/commit/98f63f0c40cbdcd40e14704379f28c19c436a6c2))
* rubocop offenses — formatting, guard clauses, predicate rename extract_flag? ([43341be](https://github.com/patrick204nqh/browserctl/commit/43341be50f12ca28699b009efb85b1ff404e4dab))
* trigger release workflow on GitHub release publication ([55c8faa](https://github.com/patrick204nqh/browserctl/commit/55c8faae8d753f35663ebd3c02996d1a602de091))
* update brand icon concept and roadmap versioning ([7a97b4b](https://github.com/patrick204nqh/browserctl/commit/7a97b4b0c0eaffbd8743ac30b2fbf13be468c80e))

## [0.1.1](https://github.com/patrick204nqh/browserctl/compare/v0.1.0...v0.1.1) (2026-04-19)


### Bug Fixes

* resolve rubocop offenses in gemspec ([dfb67dc](https://github.com/patrick204nqh/browserctl/commit/dfb67dc135d9538847a2b58a17d1dd03b7ab4b45))
* synchronize access to pages in CommandDispatcher methods ([c61d129](https://github.com/patrick204nqh/browserctl/commit/c61d129076026d8cae200fdbebb2337f9feccd70))

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

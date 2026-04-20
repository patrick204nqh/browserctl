# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0](https://github.com/patrick204nqh/browserctl/compare/v0.2.1...v0.3.0) (2026-04-20)


### Features

* add .rspec configuration for test exclusion and output format ([8afec4d](https://github.com/patrick204nqh/browserctl/commit/8afec4d50ae57f591be2c01ee933d562f957b4e5))
* add "no-sandbox" option to browser initialization for improved compatibility ([8f668e9](https://github.com/patrick204nqh/browserctl/commit/8f668e9404a243c496dbd89b574375ee7a6476da))
* add architecture documentation and decision records with diagrams ([9b67e40](https://github.com/patrick204nqh/browserctl/commit/9b67e40892cb87a075818fd7b166584a48c8edff))
* add CODEOWNERS file and require code owner review for pull requests ([b754b99](https://github.com/patrick204nqh/browserctl/commit/b754b99b4e5732b0f19955d17998330583ed0bbe))
* add GitHub Actions workflow for releasing to RubyGems ([27114d4](https://github.com/patrick204nqh/browserctl/commit/27114d4808449628c7501c04e2d3472019bc484b))
* add logging functionality and environment variable setup documentation ([feb529c](https://github.com/patrick204nqh/browserctl/commit/feb529c4040c6f84104fa6dc55afc8d0a5d1b1a7))
* add record command — capture session as replayable workflow ([bb8988b](https://github.com/patrick204nqh/browserctl/commit/bb8988bcf17c0a7689f5a6e53d755d0e6a69b359))
* add ref registry and diff cache to CommandDispatcher ([217e158](https://github.com/patrick204nqh/browserctl/commit/217e15831b2cf1f0bf693584f47ed5d315594803))
* add ref-based click and fill using snapshot registry ([f0251c0](https://github.com/patrick204nqh/browserctl/commit/f0251c0732fd535bde8746b2817d3674ec8bc353))
* add repository rulesets for branch and release tag protection ([f55ff9d](https://github.com/patrick204nqh/browserctl/commit/f55ff9d6f89dbd65e7906572ebed779a57388458))
* add retry_count and timeout options to workflow steps ([7b5e694](https://github.com/patrick204nqh/browserctl/commit/7b5e694cfb246396502a07b02928de79233a715f))
* add smoke_the_internet example, support file path in browserctl run ([db23891](https://github.com/patrick204nqh/browserctl/commit/db23891a3f021dc1f76451dd95805485b6a5e6d7))
* add snap --diff returning only changed elements ([0a09558](https://github.com/patrick204nqh/browserctl/commit/0a095583ea23b1cff0df1ecc6cb91a3e35039e2c))
* add watch command — poll selector and emit when found ([b9a3abf](https://github.com/patrick204nqh/browserctl/commit/b9a3abf15b7e021906dda940f29f029ca3c221c2))
* align CLI with standard conventions ([f278ea1](https://github.com/patrick204nqh/browserctl/commit/f278ea12cfc7e205d5d014b1edf3f8370582b67a))
* enhance CI workflows with release automation and timeout settings ([d035234](https://github.com/patrick204nqh/browserctl/commit/d035234e754dc9a3867d657d7a7a76dcbc2c53b5))
* named daemon instances via browserd --name and multi-socket support ([8cbc62d](https://github.com/patrick204nqh/browserctl/commit/8cbc62d6c8931b23cbf31e7285ee52c62e280f5c))
* refactor browser initialization and response handling in client and server ([ca04bd6](https://github.com/patrick204nqh/browserctl/commit/ca04bd6d7e32fbcd2ab5690500465df5341c6804))
* update README and SKILL documentation with workflow examples and best practices ([1f8d265](https://github.com/patrick204nqh/browserctl/commit/1f8d2653416f3cccefec2d1e3032edbd840dfaaa))
* v0.2 AI-first enhancements ([d3246d4](https://github.com/patrick204nqh/browserctl/commit/d3246d4c861430fda1e7dfa1cb67ce22db33dd68))


### Bug Fixes

* add edited event and workflow_dispatch to release trigger ([b851306](https://github.com/patrick204nqh/browserctl/commit/b85130603986ea5a667f2a89e9af7139c38491f2))
* add paths-ignore for markdown and docs in CI workflow ([3b7801d](https://github.com/patrick204nqh/browserctl/commit/3b7801dfa536ea0b0cd9bab189f237a2709e1515))
* add x86_64-linux platform to Gemfile.lock for CI compatibility ([93514bc](https://github.com/patrick204nqh/browserctl/commit/93514bc977d2b6042d4cfa02cb556f5ec46f75d9))
* bump lint job to Ruby 3.3 — parallel 2.0.1 requires &gt;= 3.3 ([7b1baba](https://github.com/patrick204nqh/browserctl/commit/7b1baba5501f9f391c60eb847fb3c273420be686))
* capture screenshots after adding/removing elements and logging in ([9510102](https://github.com/patrick204nqh/browserctl/commit/9510102d95ec6b194011c344ca26e4c39ca0657c))
* capture wait_for_selector result once, add shutdown test ([4823163](https://github.com/patrick204nqh/browserctl/commit/4823163b4ac5d68630320d8a78dcde9c3b0af9f6))
* describe_workflow after StepDef refactor; skip nil-selector recording for ref commands ([9e437fa](https://github.com/patrick204nqh/browserctl/commit/9e437fa9c18b6c94259a652af238377ce120d12e))
* fill --ref uses --value flag; add record generate subcommand ([ef3ed43](https://github.com/patrick204nqh/browserctl/commit/ef3ed433e09c0ae8ac6e241949ee9c2c0ccaa03c))
* move --version check before full library load; bump to 0.2.1 ([8371c2e](https://github.com/patrick204nqh/browserctl/commit/8371c2e7222e7ade01fd5f60c3911d1deafc2564))
* nil-safety in ancestors_until_html, break after shutdown in IdleWatcher ([733aa38](https://github.com/patrick204nqh/browserctl/commit/733aa383b9a825bc1d2cc89efcbb58cc3dbfa02c))
* prevent CI hang on daemon shutdown ([835319e](https://github.com/patrick204nqh/browserctl/commit/835319ed26367a41c024a1f1e8dc4b9ea64675fc))
* refactor cmd_open_page to directly navigate to URL and update tests ([2ec18de](https://github.com/patrick204nqh/browserctl/commit/2ec18de6d9554160d6ba9f4bd03ce52353dac860))
* remove 'edited' type from release trigger events ([98f63f0](https://github.com/patrick204nqh/browserctl/commit/98f63f0c40cbdcd40e14704379f28c19c436a6c2))
* resolve all rubocop offenses for clean lint ([42b3a4f](https://github.com/patrick204nqh/browserctl/commit/42b3a4fcc6219dfff32460a4b1ece5fa53a21101))
* resolve rubocop offenses in gemspec ([dfb67dc](https://github.com/patrick204nqh/browserctl/commit/dfb67dc135d9538847a2b58a17d1dd03b7ab4b45))
* rubocop offenses — formatting, guard clauses, predicate rename extract_flag? ([43341be](https://github.com/patrick204nqh/browserctl/commit/43341be50f12ca28699b009efb85b1ff404e4dab))
* synchronize access to pages in CommandDispatcher methods ([c61d129](https://github.com/patrick204nqh/browserctl/commit/c61d129076026d8cae200fdbebb2337f9feccd70))
* thread-safe last_used, close server in teardown, restore failed StepResult, fix invoke stack pop ([f6bdfa2](https://github.com/patrick204nqh/browserctl/commit/f6bdfa220afc6eaad19d6815c025eeaa74d5dc85))
* trigger release workflow on GitHub release publication ([55c8faa](https://github.com/patrick204nqh/browserctl/commit/55c8faae8d753f35663ebd3c02996d1a602de091))
* update brand icon concept and roadmap versioning ([7a97b4b](https://github.com/patrick204nqh/browserctl/commit/7a97b4b0c0eaffbd8743ac30b2fbf13be468c80e))
* use GH_PAT for release-please to trigger release workflow ([da83358](https://github.com/patrick204nqh/browserctl/commit/da83358e8ff19e8a30c23b9f5d744cb11ffbc7c6))
* use PAT for release-please to trigger release workflow ([4a9ea99](https://github.com/patrick204nqh/browserctl/commit/4a9ea99f418cbf719a16e2a971672175e0292221))

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

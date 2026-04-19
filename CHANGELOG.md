# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Thread safety: all server dispatch calls now protected by a Mutex
- `fill` no longer queries the DOM twice; returns an error if selector is not found
- `click` now returns an error when the selector is not found instead of silently succeeding
- `wait_for` now polls for the selector until timeout instead of checking once after network idle
- Circular workflow `invoke` calls now raise a descriptive `WorkflowError`

### Added
- GitHub Actions CI (lint + test across Ruby 3.2–3.4)
- Gemspec metadata: `changelog_uri`, `source_code_uri`, `bug_tracker_uri`, `rubygems_mfa_required`

## [0.1.0] - 2025-01-01

### Added
- Initial release: persistent browser daemon (`browserd`) over Unix socket
- CLI (`browserctl`) with commands: open, close, pages, goto, fill, click, shot, snap, url, eval, ping, shutdown
- Ruby workflow DSL with params, steps, assertions, and `invoke`
- AI-optimized DOM snapshot format (JSON with ref IDs)
- Ferrum-backed Chrome/Chromium automation

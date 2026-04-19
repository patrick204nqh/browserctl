# Contributing to browserctl

Thank you for taking the time to contribute! This guide covers everything you need to get started.

## Table of Contents

- [Development Setup](#development-setup)
- [Running Tests](#running-tests)
- [Code Style](#code-style)
- [Submitting Changes](#submitting-changes)
- [Releasing](#releasing)
- [Reporting Bugs](#reporting-bugs)
- [Requesting Features](#requesting-features)

---

## Development Setup

**Requirements:** Ruby >= 3.2, Chrome or Chromium on `PATH`

```bash
git clone https://github.com/patrick204nqh/browserctl
cd browserctl
bin/setup
```

`bin/setup` installs gem dependencies and checks for Chrome/Chromium.

---

## Running Tests

```bash
bundle exec rspec           # full suite
bundle exec rspec spec/unit # unit tests only (no browser required)
```

Integration tests in `spec/integration/` require a running Chrome/Chromium. They are skipped automatically if the browser is not available.

---

## Code Style

This project uses RuboCop. Run it before submitting:

```bash
bundle exec rubocop
bundle exec rubocop -A  # auto-fix safe offenses
```

Configuration lives in `.rubocop.yml`. Please keep new code consistent with the existing style.

---

## Submitting Changes

1. Fork the repository and create a branch from `main`:
   ```bash
   git checkout -b fix/describe-your-change
   ```
2. Make your changes. Add or update tests for any behavior you change.
3. Ensure the full test suite passes and RuboCop reports no offenses.
4. Open a pull request against `main`. Fill in the PR template — describe what changed and why.

**Branch naming conventions:**
- `fix/<short-description>` — bug fixes
- `feat/<short-description>` — new features
- `chore/<short-description>` — maintenance, refactoring, deps

---

## Releasing

Releases are published to [RubyGems](https://rubygems.org/gems/browserctl) by pushing a version tag. The `release` GitHub Actions workflow handles building and pushing the gem automatically.

**Prerequisites:** you must be a maintainer with access to the `rubygems-release` GitHub Environment. The `RUBYGEMS_API_KEY` secret is provisioned via the infrastructure repo — no manual setup needed.

### Steps

1. **Update the changelog**

   Move everything under `## [Unreleased]` into a new versioned section in `CHANGELOG.md`:

   ```markdown
   ## [0.2.0] - 2026-04-19

   ### Added
   - ...
   ```

2. **Bump the version**

   Edit `lib/browserctl/version.rb`:

   ```ruby
   VERSION = "0.2.0"
   ```

3. **Commit and push**

   ```bash
   git add CHANGELOG.md lib/browserctl/version.rb
   git commit -m "chore: release v0.2.0"
   git push origin main
   ```

4. **Tag the release**

   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```

   Pushing the tag triggers the `release` workflow, which builds the gem and pushes it to RubyGems. You can monitor progress in the **Actions** tab on GitHub.

5. **Verify**

   Check that the new version appears at `https://rubygems.org/gems/browserctl`. The gem should be live within a minute of the workflow completing.

### Version numbering

This project follows [Semantic Versioning](https://semver.org):

- **Patch** (`0.1.x`) — bug fixes only, no API changes
- **Minor** (`0.x.0`) — new backwards-compatible functionality
- **Major** (`x.0.0`) — breaking changes

---

## Reporting Bugs

Open an issue at [github.com/patrick204nqh/browserctl/issues](https://github.com/patrick204nqh/browserctl/issues). Include:

- Ruby version (`ruby --version`)
- Chrome/Chromium version (`google-chrome --version`)
- OS and version
- Steps to reproduce
- Expected vs. actual behavior
- Relevant logs or error output

---

## Requesting Features

Open an issue describing the use case you're trying to solve — not just the feature you want. This helps evaluate fit and find the right design. Check existing issues first to avoid duplicates.

---

## Security Issues

Please do **not** open a public issue for security vulnerabilities. See [SECURITY.md](SECURITY.md) for the responsible disclosure process.

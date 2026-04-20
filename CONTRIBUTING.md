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

## Environment Variables

Copy `.envrc.example` to `.envrc` and fill in your values:

```bash
cp .envrc.example .envrc
```

`.envrc` is listed in `.gitignore` and will never be committed. Use [direnv](https://direnv.net) to load it automatically (`direnv allow`), or `source .envrc` manually.

| Variable | Required | Purpose |
|----------|----------|---------|
| `GH_TOKEN` | Maintainers only | GitHub personal access token used by release-please to open Release PRs and create GitHub Releases. Needs `repo` scope. |

Day-to-day development (running tests, linting, using the daemon) does not require any environment variables.

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

Releases are automated via [release-please](https://github.com/googleapis/release-please). Every commit to `main` that follows the [Conventional Commits](https://www.conventionalcommits.org) format is picked up automatically.

**Prerequisites:** you must be a maintainer with access to the `rubygems-release` GitHub Environment. The `RUBYGEMS_API_KEY` secret is provisioned via the infrastructure repo — no manual setup needed.

### How it works

```
conventional commit → main
        ↓
release-please opens (or updates) a Release PR
  • bumps lib/browserctl/version.rb
  • updates CHANGELOG.md
        ↓
maintainer reviews and merges the Release PR
        ↓
release-please creates a GitHub Release + tag (e.g. v0.2.0)
        ↓
release workflow triggers → gem built and pushed to RubyGems
```

### Steps

1. **Write conventional commits** as you work — release-please reads these to determine the next version and generate the changelog:

   | Prefix | Version bump | Example |
   |--------|-------------|---------|
   | `fix:` | patch | `fix: handle nil selector in click` |
   | `feat:` | minor | `feat: add scroll command` |
   | `feat!:` or `BREAKING CHANGE:` | major | `feat!: rename goto to navigate` |
   | `chore:`, `docs:`, `refactor:` | none | skipped in changelog |

2. **Merge your PR** — the `release-please` workflow runs on every push to `main` and keeps the Release PR up to date.

3. **Review and merge the Release PR** — when you're ready to ship, merge the open "chore: release vX.Y.Z" PR. That's it.

   The `release` workflow then builds the gem and pushes it to RubyGems automatically. Monitor progress in the **Actions** tab.

4. **Verify** — check that the new version appears at `https://rubygems.org/gems/browserctl` within a minute of the workflow completing.

### Version numbering

This project follows [Semantic Versioning](https://semver.org). release-please determines the bump automatically from commit prefixes — no manual version editing needed.

- **Patch** (`0.1.x`) — `fix:` commits only
- **Minor** (`0.x.0`) — at least one `feat:` commit
- **Major** (`x.0.0`) — any `feat!:` or `BREAKING CHANGE:` footer

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

# Contributing to browserctl

Thank you for taking the time to contribute! This guide covers everything you need to get started.

## Table of Contents

- [Development Setup](#development-setup)
- [Running Tests](#running-tests)
- [Code Style](#code-style)
- [Submitting Changes](#submitting-changes)
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

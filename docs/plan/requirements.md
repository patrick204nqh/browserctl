# Requirements Document — browserctl v0.4 Hardening

## Introduction

This document captures requirements for six targeted improvements to browserctl v0.3.1 identified during a post-release review. The changes address security hardening, session reproducibility, cross-step state management, credential separation, and distribution consistency. All changes are additive and backwards-compatible with existing workflows.

## Glossary

- **JSONL recording**: Newline-delimited JSON file written to `/tmp/browserctl-recordings/` that captures automation commands for workflow generation
- **Cookie export/import**: Persisting Ferrum page cookies to/from a project-local JSON file under `.browserctl/sessions/` to enable session reuse across daemon restarts
- **WorkflowContext**: The Ruby object that steps execute within — provides `page()`, `client`, param access, and soon `store`/`fetch`
- **Params file**: A YAML or JSON file holding workflow input values (including secrets) kept outside the codebase
- **Token-like param**: A URL query parameter whose name matches patterns like `token`, `key`, `secret`, `auth`, `code`, `access_token`, `api_key`

---

## Requirements

### Requirement 1 — Ruby version pin

**User Story:** As a gem maintainer, I want the declared minimum Ruby version to match the tested version, so that users are not misled into expecting support for an untested runtime.

#### Acceptance Criteria

1. WHEN a user inspects the gemspec, THE `required_ruby_version` field SHALL read `>= 3.3`.
2. THE CI workflow job name SHALL remain `Test (Ruby 3.3)` consistent with the pin.
3. THE homebrew-tap formula SHALL continue to resolve to a compatible Ruby (3.3+).

---

### Requirement 2 — Secure recording file permissions

**User Story:** As a security-conscious user, I want recording JSONL files to be readable only by my own account, so that other OS users on shared machines cannot inspect captured selectors and URLs.

#### Acceptance Criteria

1. WHEN `browserctl record start <name>` is run, THE JSONL log file in `/tmp/browserctl-recordings/` SHALL be created with mode `0600` before any data is written.
2. IF the file already existed from a previous run, THE system SHALL remove it and recreate it with `0600` permissions.
3. THE recordings directory itself SHALL be created with mode `0700`.

---

### Requirement 3 — Cross-step state in WorkflowContext

**User Story:** As a workflow author, I want to pass a value extracted in one step to a later step, so that I can implement multi-tab flows such as reading an OTP code from a mailbox and entering it on the target site.

#### Acceptance Criteria

1. WHEN `store(:key, value)` is called inside any step block, THE value SHALL be retrievable by `fetch(:key)` in subsequent steps within the same workflow run.
2. IF `fetch(:key)` is called for a key that has not been stored, THE system SHALL raise a descriptive `KeyError` naming the missing key.
3. THE `store` and `fetch` methods SHALL be available without any additional require or setup.
4. THE stored values SHALL NOT persist across separate `browserctl run` invocations.
5. THE stored keys SHALL NOT conflict with declared `param` names (param names remain accessible via `method_missing`).

---

### Requirement 4 — Cookie export and import

**User Story:** As an automation author, I want to save authenticated browser cookies to a file and restore them in a future session, so that I can skip interactive login steps when re-running workflows.

#### Acceptance Criteria

1. WHEN `browserctl export-cookies <page> <path>` is run, THE command SHALL write a JSON array of all cookies for the named page to the specified file path.
2. WHEN `browserctl import-cookies <page> <path>` is run, THE command SHALL read the JSON file and set each cookie on the named page via the existing `set_cookie` command.
3. THE exported JSON format SHALL include at minimum `name`, `value`, `domain`, `path`, `httpOnly`, `secure`, and `expires` fields for each cookie.
4. THE export format SHALL round-trip: a file exported then imported SHALL restore equivalent cookies.
5. IF the file path for import does not exist, THE system SHALL print a clear error and exit non-zero.
6. THE `Client` class SHALL expose `export_cookies(name, path)` and `import_cookies(name, path)` methods usable from workflow DSL.

---

### Requirement 5 — Params file loading

**User Story:** As a workflow author, I want to store sensitive credentials in a local git-ignored file and reference it at run time, so that passwords and tokens never appear in command-line history or workflow source files.

#### Acceptance Criteria

1. WHEN `browserctl run <workflow> --params <file>` is invoked, THE runner SHALL load the YAML or JSON file and merge its keys (as symbols) into the workflow params.
2. WHERE both a params file and a CLI `--set key=value` flag provide the same key, THE CLI flag SHALL win.
3. IF the params file does not exist, THE system SHALL print a clear error and exit non-zero.
4. IF the params file contains invalid YAML/JSON, THE system SHALL print a parse error and exit non-zero.
5. THE params file SHALL support both YAML (`.yml`, `.yaml`) and JSON (`.json`) extensions.
6. THE params file path SHALL be accepted by the existing `browserctl run` CLI subcommand with no breaking change to existing invocations.

---

### Requirement 6 — Filter token-like query params from recorded goto URLs

**User Story:** As a security-conscious user, I want OAuth codes, API keys, and other credential-bearing query parameters to be stripped from recorded `goto` URLs, so that generated workflow files do not contain sensitive tokens.

#### Acceptance Criteria

1. WHEN a `goto` command is recorded and the URL contains a query parameter whose name matches `/^(token|key|secret|auth|code|access_token|api_key|client_secret|state)/i`, THE recorded URL SHALL have those parameters replaced with a `[REDACTED]` placeholder value.
2. THE redaction SHALL apply only to the JSONL recording; the actual navigation SHALL use the original URL.
3. WHEN the workflow is generated from the recording, THE generated step SHALL contain the redacted URL with a comment indicating parameters were filtered.
4. IF no sensitive parameters are present, THE URL SHALL be recorded unchanged.

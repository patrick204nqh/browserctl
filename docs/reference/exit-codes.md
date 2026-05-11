# browserctl Exit Codes

The `browserctl` CLI exits with a small, stable set of integer status codes so AI agents and shell scripts can branch on `$?` without parsing stderr.

The mapping is implemented in [`lib/browserctl/error/exit_codes.rb`](../../lib/browserctl/error/exit_codes.rb) and lives in the **Stable** zone (see [api-stability.md](api-stability.md)) — codes will not be renumbered without a major version bump.

For the meaning of each `Codes::*` string and its suggested-action template, see [errors.md](errors.md).

## Table

| Exit code | Name                 | Meaning                                                                                  | Mapped `Codes::*`             | Example trigger                                                                  |
| --------- | -------------------- | ---------------------------------------------------------------------------------------- | ----------------------------- | -------------------------------------------------------------------------------- |
| `0`       | `OK`                 | Success.                                                                                 | —                             | Any command returning a normal result.                                           |
| `1`       | `GENERIC`            | Catch-all for errors not (yet) assigned a dedicated code. Always the safe fallback.      | `GENERIC`, plus any unmapped code (e.g. `DOMAIN_NOT_ALLOWED`, `KEY_NOT_FOUND`, `SECRET_RESOLUTION_FAILED`) | `state load <missing>`; allowlist denial.                                        |
| `2`       | `DRIFT`              | **Reserved.** Allocated for an upcoming snapshot/selector drift signal in a later v0.12 PR. Currently unmapped — drift conditions surface as `GENERIC`. | _none yet_                    | _(reserved)_                                                                     |
| `3`       | `AUTH_REQUIRED`      | The page or state bundle requires re-authentication. Rotate the bound flow and retry.   | `AUTH_REQUIRED`               | `auth-check` against a logged-out session; `state load` on an expired bundle whose flow re-runs. |
| `4`       | `DAEMON_UNREACHABLE` | The CLI could not reach the daemon socket.                                              | `DAEMON_UNREACHABLE`          | Daemon not started, wrong `--daemon` name, or socket file missing.               |
| `5`       | `PROTOCOL_MISMATCH`  | A persisted artifact's `version:` header is newer (or otherwise unsupported) than this build can read. | `PROTOCOL_MISMATCH`           | Loading a state bundle, recording, or workflow saved by a future browserctl.     |
| `6`       | `SELECTOR_NOT_FOUND` | A CSS selector or stable ref did not match anything on the page.                        | `SELECTOR_NOT_FOUND`          | `click <page> "#missing"`; ref invalidated by a re-render.                       |
| `7`       | `STATE_EXPIRED`      | A state bundle's TTL window has passed and it cannot be safely reused.                  | `STATE_EXPIRED`               | `state load` on a bundle past its `expires_at`.                                  |
| `8`       | `VALIDATION_FAILED`  | A caller-side validation guard rejected the request. Covers the whole `VALIDATION_FAILED` family — agents can branch on `$? == 8` for any validation failure without caring which specific guard tripped. | `VALIDATION_FAILED`, `INVALID_SELECTOR_REF`, `INVALID_STATE_NAME`, `INVALID_DSL_USAGE`, `INVALID_FORMAT_VERSION` | `click` with no selector or ref; `state save "bad name!"`; flow DSL missing a required block. |

## Lookup contract

`Browserctl::Error::ExitCodes.for(code)`:

- Returns the integer above for any known `Codes::*` string.
- Returns `1` (`GENERIC`) for `nil` or any code without an explicit entry.
- Never raises.

This is what the CLI's top-level rescue calls when a `Browserctl::Error` escapes:

```ruby
rescue Browserctl::Error => e
  # ...emit human + JSON stderr...
  exit Browserctl::Error::ExitCodes.for(e.code)
end
```

## Compatibility note (v0.12)

Prior to v0.12, the CLI exited `1` for everything except `AUTH_REQUIRED` (which already exited `7`). Scripts that hard-coded `exit 1 = error` continue to work — `1` is still the catch-all. Scripts that hard-coded `7 = AUTH_REQUIRED` must update: `AUTH_REQUIRED` is now `3`, and `7` is `STATE_EXPIRED`.

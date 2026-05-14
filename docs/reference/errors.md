# browserctl Error Reference

Every browserctl failure carries a stable, machine-readable **code**. The code — not the prose message — is the contract. The same code string surfaces in three places:

- The `code:` field of a daemon JSON-RPC error response.
- The `code` field of the JSON object the CLI prints to **stderr** on failure.
- The lookup key for the process exit status (see [exit-codes.md](exit-codes.md)).

Prose messages can change between releases for clarity. AI agents and shell scripts must branch on `code`, never on `error` / `message` text.

## Structured payload

Both the daemon wire format and the CLI's stderr line use the same shape:

```json
{
  "error": "selector \"#submit\" not found",
  "code": "SELECTOR_NOT_FOUND",
  "context": { "selector": "#submit", "page": "checkout" },
  "suggested_action": "Re-run snapshot to get fresh refs, then retry with a stable ref or selector."
}
```

The shape is built by [`Browserctl::Error#to_payload`](../../lib/browserctl/errors.rb) and the daemon's [`ErrorPayload`](../../lib/browserctl/server/handlers/error_payload.rb) helper. `context` is free-form structured fields (selector, path, ref, ...). `suggested_action` is filled from [`SuggestedActions`](../../lib/browserctl/error/suggested_actions.rb) and is always present.

## Code reference

The canonical enum lives in [`lib/browserctl/error/codes.rb`](../../lib/browserctl/error/codes.rb). Every code below is a real `Browserctl::Error::Codes` constant; conversely, every constant in `Codes::ALL` appears in this table. The drift spec at `spec/docs/errors_md_spec.rb` enforces parity.

| Code | Meaning | Typical trigger | Suggested action | Exit code | Source |
| ---- | ------- | --------------- | ---------------- | --------- | ------ |
| `AUTH_REQUIRED` | The page or state bundle requires re-authentication. | `auth-check` against a logged-out session; `state load` on an expired bundle. | Run the suggested flow to refresh credentials, then retry. | [`3`](exit-codes.md) | [codes.rb#L13](../../lib/browserctl/error/codes.rb#L13) |
| `SELECTOR_NOT_FOUND` | A CSS selector or stable ref did not match anything on the page. | `click <page> "#missing"`; ref invalidated by a re-render. | Re-run snapshot to get fresh refs, then retry with a stable ref or selector. | [`6`](exit-codes.md) | [codes.rb#L14](../../lib/browserctl/error/codes.rb#L14) |
| `STATE_EXPIRED` | A state bundle's TTL window has passed and it cannot be safely reused. | `state load` on a bundle past its `expires_at`. | Re-save the state bundle (state save) or rotate it (state rotate). | [`7`](exit-codes.md) | [codes.rb#L15](../../lib/browserctl/error/codes.rb#L15) |
| `SECRET_RESOLUTION_FAILED` | A workflow tried to resolve a secret reference and the resolver failed (missing entry, transport error, malformed ref). | `secret://op/Vault/Item/field` where the item is gone. | Verify the secret resolver config and that the underlying secret exists. | [`1`](exit-codes.md) (falls through to `GENERIC`) | [codes.rb#L16](../../lib/browserctl/error/codes.rb#L16) |
| `DAEMON_UNREACHABLE` | The CLI could not reach the daemon socket. | Daemon not started, wrong `--daemon` name, or socket file missing. | Start the daemon with 'browserctl daemon start', then retry. | [`4`](exit-codes.md) | [codes.rb#L17](../../lib/browserctl/error/codes.rb#L17) |
| `PROTOCOL_MISMATCH` | A persisted artifact's `version:` header is unsupported by this build. | Loading a state bundle, recording, or workflow saved by a future browserctl. See [format-versions.md](format-versions.md). | Upgrade browserctl to a version that supports this artifact's format version. | [`5`](exit-codes.md) | [codes.rb#L18](../../lib/browserctl/error/codes.rb#L18) |
| `DOMAIN_NOT_ALLOWED` | A navigation or action targeted a domain outside the policy allowlist. | `navigate` to a host not in `policy.yml` allowed domains. | Add the domain to your policy allowlist or use an allowed URL. | [`1`](exit-codes.md) (falls through to `GENERIC`) | [codes.rb#L19](../../lib/browserctl/error/codes.rb#L19) |
| `KEY_NOT_FOUND` | A `fetch` request asked for a daemon-scoped key that was never `store`d in this session. | `fetch foo` before a corresponding `store foo …`. | Verify the key was stored in this daemon session before fetching. | [`1`](exit-codes.md) (falls through to `GENERIC`) | [codes.rb](../../lib/browserctl/error/codes.rb) |
| `VALIDATION_FAILED` | Parent code for any caller-side validation failure. Specific guards use one of the `INVALID_*` codes below; this one is the catch-all when no specialisation fits. | DSL block missing, malformed argument, contract violation on a public API. | Check the argument or DSL usage against the documented contract, then retry. | [`8`](exit-codes.md) | [codes.rb](../../lib/browserctl/error/codes.rb) |
| `INVALID_SELECTOR_REF` | An interaction method (`click`, `fill`, `hover`, `upload`, `select`) was called without either a `selector:` or `ref:` argument. | `client.click(name: "checkout")` with neither selector nor ref. | Pass either a CSS selector or a stable ref — one is required. | [`8`](exit-codes.md) | [codes.rb](../../lib/browserctl/error/codes.rb) |
| `INVALID_STATE_NAME` | A state name failed the character/length contract. | `state save "bad name!"` — names must match `[A-Za-z0-9_-]{1,64}`. | Use only letters, digits, '_' or '-' (max 64 chars) for state names. | [`8`](exit-codes.md) | [codes.rb](../../lib/browserctl/error/codes.rb) |
| `INVALID_DSL_USAGE` | A `flow`, `workflow`, or `step` DSL call was missing a required block, name, or argument. | `precondition "x"` with no block; `compose` referencing a flow that doesn't exist; non-semver `version`. | Check the workflow/flow DSL call against docs/reference/style-guide.md; required blocks or arguments are missing. | [`8`](exit-codes.md) | [codes.rb](../../lib/browserctl/error/codes.rb) |
| `INVALID_FORMAT_VERSION` | A persisted-artifact format-version header is not a non-negative Integer. | Manually-edited bundle/recording/workflow header with `version: "foo"`. | Use a non-negative Integer for the format version header; see docs/reference/format-versions.md. | [`8`](exit-codes.md) | [codes.rb](../../lib/browserctl/error/codes.rb) |
| `INVALID_ARGUMENT` | A wire-protocol or CLI argument failed a required-value check. Introduced in v0.15 alongside the `data` verb family for `--scope` validation; reusable for any future required-value guard. | `data get --scope bogus`; `data set --scope cookies` with no `--domain`. | Check the argument value against the documented contract; for `data` use `--scope cookies\|localStorage\|sessionStorage`. | [`8`](exit-codes.md) | [codes.rb](../../lib/browserctl/error/codes.rb) |
| `GENERIC` | Catch-all for any failure not (yet) assigned a dedicated code. The safe fallback. | Unmapped raise sites; future codes that haven't earned dedicated handling yet. | See docs/reference/errors.md for guidance. (default `SuggestedActions` fallback) | [`1`](exit-codes.md) | [codes.rb](../../lib/browserctl/error/codes.rb) |

The "Exit code" column references [exit-codes.md](exit-codes.md). Codes whose row says "falls through to `GENERIC`" have no dedicated entry in [`ExitCodes::TABLE`](../../lib/browserctl/error/exit_codes.rb) and collapse to `1`. They may earn their own exit code in a future milestone.

## Programmatic handling

Branch on the `code` field, not on the prose `error`/`message`.

**Shell:**

```bash
out=$(browserctl click checkout "#submit" 2>&1 1>/dev/null)
case $(printf '%s' "$out" | jq -r '.code // "GENERIC"') in
  SELECTOR_NOT_FOUND) browserctl page snapshot checkout > /dev/null && retry ;;
  AUTH_REQUIRED)      browserctl state rotate checkout ;;
  *)                  echo "unhandled: $out" >&2; exit 1 ;;
esac
```

The CLI's exit status is also stable — see [exit-codes.md](exit-codes.md). Many scripts can branch on `$?` alone and skip JSON parsing.

**Ruby (against the daemon directly):**

```ruby
require "browserctl/client"

client = Browserctl::Client.new
begin
  client.click(name: "checkout", selector: "#submit")
rescue Browserctl::Error => e
  case e.code
  when Browserctl::Error::Codes::SELECTOR_NOT_FOUND
    client.snapshot(name: "checkout") # refresh refs, then retry
  when Browserctl::Error::Codes::AUTH_REQUIRED
    # rotate the bound flow per e.context
  else
    warn "unhandled #{e.code}: #{e.message}"
    raise
  end
end
```

The prose `e.message` is **not** stable across releases. Treat it as human-only.

## Adding a new code

1. Add a new constant to `Browserctl::Error::Codes` in `lib/browserctl/error/codes.rb`, and append it to `ALL`.
2. Add a verb-first imperative entry to `SuggestedActions::TABLE` in `lib/browserctl/error/suggested_actions.rb`. Codes without an entry fall back to `DEFAULT`, which only points at this doc.
3. Decide the exit-code mapping in `ExitCodes::TABLE` (`lib/browserctl/error/exit_codes.rb`). If the failure is operationally distinct enough to warrant its own integer, allocate one; otherwise it collapses to `GENERIC` (`1`). Update [exit-codes.md](exit-codes.md) if you allocate.
4. Add a row to the table above. The `spec/docs/errors_md_spec.rb` drift spec will fail until you do.

# ADR-0020: Error Code Taxonomy and Exit-Code Map

**Date**: 2026-05-10
**Status**: accepted
**Pairs with**: ADR-0009 (error handling strategy — this ADR is the v0.12 evolution of that decision), ADR-0004 (JSON-RPC wire format — error payloads ride on the same envelope).
**Deciders**: Patrick

## Context

Through v0.11, browserctl's error story was "raise a `Browserctl::Error` subclass with a human-readable message; let the CLI render it." That worked for humans reading a terminal. It does not work for the two callers we actually optimise for:

- **AI agents** consuming the JSON-RPC wire or CLI stderr. They need a deterministic field to switch on. Branching on prose ("Did the message contain the word 'auth'?") is a contract waiting to break the next time the message gets clearer.
- **Shell scripts** wrapping the CLI. They want `case $? in 3) reauth ;; 4) start_daemon ;; esac` — a small, stable integer space, not a regex over stderr.

The v0.10/v0.11 surface failed both: exception class identity leaked Ruby internals to non-Ruby clients, and the only reliable exit code was `1` for "anything went wrong." WS-2 in the [v0.12 plan](../../plans/v0.12-solid.md) committed to fixing this in five PRs (#128, #134, #137, #140, #141). This ADR codifies the *why* behind those PRs; the *what* lives in [`docs/reference/errors.md`](../../reference/errors.md) and [`docs/reference/exit-codes.md`](../../reference/exit-codes.md).

## Decision

### Typed errors with stable string codes

Every `Browserctl::Error` carries a `code:` — a `SCREAMING_SNAKE_CASE` string drawn from a single canonical enum (`Browserctl::Error::Codes`, `lib/browserctl/error/codes.rb`). The code, not the exception class and not the prose, is the contract.

The choice of *string codes* over *exception class identity* is deliberate:

- The wire is JSON-RPC, not Ruby. A non-Ruby client cannot rescue `Browserctl::SelectorNotFound`; it can match `"code": "SELECTOR_NOT_FOUND"`. The string survives serialisation and language boundaries; the class doesn't.
- Class hierarchies invite refactors. Renaming `Browserctl::SelectorNotFound` to `Browserctl::Selector::NotFound` is a normal Ruby change that would silently break every consumer doing `rescue Browserctl::SelectorNotFound`. The string `"SELECTOR_NOT_FOUND"` is a value, not a name in a namespace, so it does not move when the code is reorganised.
- The code is decoupled from the raise site. The same code can be raised from three different layers (selector resolver, ref resolver, action handler) without forcing them into a shared class hierarchy.

The choice over *error-message regex parsing* is the same argument one level up: prose is for humans and changes for clarity; codes are for machines and don't.

### Stability guarantee

Codes never change once shipped. New codes are appended to `Codes::ALL`. Deprecation requires a minor cycle: the code stays in `ALL` and the wire for one minor version, marked deprecated in the reference doc; only then does it leave. This matches the api-stability tier the reference docs declare ("Stable" zone in [api-stability.md](../../reference/api-stability.md)).

The `GENERIC` code is the safe fallback for any failure that hasn't earned a dedicated code yet. New code paths that don't yet have a taxonomy entry raise `GENERIC` and inherit the catch-all exit `1`. This means we never block a feature on bikeshedding a new constant, and we never invent a code that we later regret.

### Structured error payload

Both the daemon JSON-RPC error response and the CLI's stderr line carry the same shape, built by `Browserctl::Error#to_payload`:

```json
{
  "code": "SELECTOR_NOT_FOUND",
  "message": "selector \"#submit\" not found",
  "context": { "selector": "#submit", "page": "checkout" },
  "suggested_action": "Re-run snapshot to get fresh refs, then retry with a stable ref or selector."
}
```

Four fields, each pulling its weight:

- **`code`** — the contract. Branch on this.
- **`message`** — for humans. May change for clarity between releases. Never matched against by callers.
- **`context`** — free-form structured fields the caller might need to recover (selector, path, ref, bundle name). Keeps recovery code from re-parsing the message to extract the value the raiser already knew.
- **`suggested_action`** — a verb-first imperative sentence pulled from `SuggestedActions::TABLE`. Always present; missing entries fall back to a default that points at the reference doc. The point is to give the agent (or human) one concrete next move per code, written once at the raise definition site rather than re-derived at every catch site.

The same shape on the wire and on stderr means a script can `jq` the CLI output the same way it would `jq` a daemon response. No second parser, no second mental model.

### Exit-code map

The CLI's top-level rescue calls `Browserctl::Error::ExitCodes.for(code)` and exits with the resulting integer. The map is small and stable:

| Exit | Code(s) | Why this category gets its own integer |
| ---- | ------- | -------------------------------------- |
| `0` | — | Success. Universal Unix convention. |
| `1` | `GENERIC` (and any unmapped code) | Catch-all. Scripts that hard-coded "non-zero = failure" continue to work. |
| `2` | _reserved for `DRIFT`_ | Drift is the v0.12 signature signal. Agents need to distinguish "your selector is gone" from "the snapshot has cosmetically changed but the workflow still passed" — different recovery, different urgency. Reserved now; mapped when the drift exit-code surfaces in a follow-up PR. |
| `3` | `AUTH_REQUIRED` | Triggers a flow rotate. Distinct from generic failure because the recovery is automatic and well-defined: re-run the suggested flow. |
| `4` | `DAEMON_UNREACHABLE` | Triggers `daemon start` (or surfaces the wrong `--daemon` name). The recovery path is *out of band* of any browser action; conflating it with generic failure hides a class of script bugs. |
| `5` | `PROTOCOL_MISMATCH` | Triggers an upgrade prompt. The artefact is fine; the build is wrong. Distinct because the user action is "upgrade browserctl," not "fix your input." |
| `6` | `SELECTOR_NOT_FOUND` | The most common recoverable failure in agent loops: refresh snapshot, retry. Agents loop on this code dozens of times in normal operation; it earns its own integer. |
| `7` | `STATE_EXPIRED` | Triggers `state save` / `state rotate`. Distinct from `AUTH_REQUIRED` because the bundle is *known* expired (TTL passed) before any auth check runs — the recovery is bookkeeping, not credential refresh. |

Each integer corresponds to a *distinct recovery action a script or agent would take*. Codes that share a recovery (or have no canonical recovery yet) collapse to `1`. This is the discriminating principle: the exit code namespace is small precisely because each entry has to justify itself by being something a caller will actually branch on.

The pre-v0.12 compatibility note (`AUTH_REQUIRED` was `7`, now `3`; `7` is now `STATE_EXPIRED`) is the cost of adopting the taxonomy late. We took it once, with a release note, rather than carrying the historical mapping forever.

### RuboCop cop: typed-errors-on-new-code

A custom cop (`Browserctl/TypedError`, in the project's `.rubocop.yml`) flags `raise Browserctl::Error.new(…)` without a `code:` and `raise StandardError, "…"` from inside `lib/browserctl/`. Scope is **changed lines and new files** (via `Include`/`Exclude` on the cop, not via Git diffs at runtime — the cop is a static check, but the `.rubocop_todo.yml` baseline pins the existing legacy untouched until those files are refactored). Legacy raise sites do not block new work; new raise sites do not get to skip the discipline.

This is the structural reason the taxonomy actually holds. Without the cop, a tired contributor adds one untyped raise and the contract has a hole. With the cop, the discipline is one line per raise: pick a code, pick a context hash, write the message. The PR fails CI otherwise.

## Alternatives Considered

### Numeric error codes (e.g. `1001`, `1002`)

- **Pros**: Compact on the wire; familiar from POSIX, gRPC.
- **Cons**: Opaque at every read site. Reading a log line that says `"code": 1004` tells you nothing; `"code": "SELECTOR_NOT_FOUND"` tells you everything you need to act. Numeric codes also tempt range-encoding ("4xx for client errors") which we don't want in this domain.
- **Why not**: We have eight codes, not eight hundred. Strings cost a few bytes per response and pay back in every grep, every dashboard filter, every agent prompt that includes a recent error.

### HTTP-status-style codes (e.g. `404`, `409`, `503`)

- **Pros**: Universally familiar; existing tooling for grouping.
- **Cons**: Wrong domain. `404` for `SELECTOR_NOT_FOUND` is a metaphor at best — the selector isn't a URL, the failure isn't a request, and the intuition HTTP status carries (about caching, idempotency, retry) is misleading here. We'd be dressing browser-automation errors as web errors and letting the dressing leak into how callers reason about them.
- **Why not**: The vocabulary should fit the domain. Browser automation has its own failure modes; they get their own names.

### Exception classes only (no string code)

- **Pros**: Idiomatic Ruby; one less concept on the inside.
- **Cons**: Leaks Ruby internals to every non-Ruby client. A Python agent talking to the daemon over the JSON-RPC wire cannot rescue `Browserctl::SelectorNotFound`; it can only see whatever serialisation we chose. If that serialisation is the class name, we've now made the class name a wire contract — and renaming the class becomes a breaking change to the wire. The string code decouples the wire contract from the Ruby internals on purpose.
- **Why not**: We need a contract that survives the language boundary. Class identity doesn't.

### Per-error-class exit codes (one integer per class)

- **Pros**: Maximum information density in `$?`.
- **Cons**: A bash script's `case` statement does not want to know about every error class browserctl can raise. The exit code namespace is for actionable categories, not for reflecting the internal class hierarchy. A script that branches on twenty exit codes is a script that should be reading the JSON payload instead.
- **Why not**: Exit codes are a coarse signalling channel. They earn their place by being branched on; collapsing siblings keeps the namespace small enough to memorise.

## Consequences

### Positive

- Agents can `switch (response.code)` and shell scripts can `case $?` deterministically. No prose parsing, no class-name introspection.
- The CLI exit code is now a contract. Scripts written today against `3 = AUTH_REQUIRED` keep working as long as the major version doesn't bump.
- Adding a new code is a four-step checklist (codes.rb / suggested_actions.rb / exit_codes.rb / errors.md), enforced by a drift spec (`spec/docs/errors_md_spec.rb`). The taxonomy stays in sync with the reference doc by construction.
- One-line discipline on every new `raise`: pick a code, pass a context hash. The cop makes this the path of least resistance.

### Negative

- **A second source of truth.** Both the exception class (for Ruby callers using `rescue`) and the string code (for everyone else) describe the same failure. We accept the redundancy because the alternative — picking one — fails one of the two audiences. The class and the code are kept in sync by `default_code` on each subclass and by the cop.
- **Pre-v0.12 exit-code remap.** Scripts hard-coded against the old `7 = AUTH_REQUIRED` mapping break on upgrade. Documented in [exit-codes.md](../../reference/exit-codes.md) and accepted as a one-time cost.

### Risks

- **Code-bloat drift.** Every new feature is tempted to mint a new code. Mitigation: `GENERIC` is the explicit good-enough fallback; reviewers push back on new codes that don't have a distinct recovery action. The four-step checklist makes adding a code visible enough to debate.
- **Silent legacy untyped raises.** The cop's baseline pins existing untyped raises as accepted. Until those files are refactored, they continue to surface as `GENERIC`. Mitigation: each legacy raise is a known item; refactors retire them as the surrounding code changes.
- **Suggested-action staleness.** A code's suggested action is written once and may drift from reality as the recovery path evolves. Mitigation: the action lives next to the code (`SuggestedActions::TABLE`), so it is reviewed at every code-touching PR; the drift spec catches deletions but not staleness — that one's on the author.

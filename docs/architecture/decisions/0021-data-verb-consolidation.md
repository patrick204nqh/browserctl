# ADR-0021: Consolidate cookie and storage verbs under a single `data` verb

**Date**: 2026-05-14
**Status**: Accepted — implemented v0.15, aliases removed v0.16
**Pairs with**: ADR-0004 (JSON-RPC wire format — the new verb rides the same envelope), ADR-0020 (error taxonomy — the new verb reuses the existing code set).
**Deciders**: Patrick (pending sign-off on verb name)

## Context

The Fixed zone today contains two parallel command families for browser-side persistence:

- **Cookies** (`lib/browserctl/server/handlers/cookies.rb`, `lib/browserctl/commands/cookie.rb`): `cookies`, `set_cookie`, `delete_cookies`, `import_cookies`, plus a client-side `export_cookies`.
- **Web storage** (`lib/browserctl/server/handlers/storage.rb`, `lib/browserctl/commands/storage.rb`): `storage_get`, `storage_set`, `storage_export`, `storage_import`, `storage_delete`.

The split is a browser-platform distinction (HTTP cookies vs. `localStorage` / `sessionStorage`) leaking into the public API. From a caller's point of view all three are "named, persistent, page-scoped, browser-side key/value buckets." The shapes mirror each other deliberately — the same verbs (get / set / list / delete / import / export) appear in both families — but with cosmetic divergences in operation names (`cookies` list vs. `storage_get` single-key), flag names (no flag for cookies; `--store local|session` for storage), and response fields (`{ cookies: [...] }` vs. `{ value: ... }` vs. `{ key_count: N }`).

`docs/reference/api-stability.md` lines 158-175 ("Known overlapping surfaces — consolidation deferred to v2.0") already names this problem and parks it. The deferral was made for a reason — re-locking the Fixed zone is expensive — but **deferring to v2.0 commits us to shipping both shapes for the entire v1.x line**, which on the current soak schedule is at least a year of maintenance. v0.15 is the last milestone where the 1.0 surface can move (see `docs/plans/v0.15-lock.md`). Once 1.0 cuts, both families are frozen; the only way to retire one becomes a 2.0 break.

The cost of doing it now is one breaking-change PR plus a one-release deprecation window. The cost of deferring is two years of two-API maintenance plus a 2.0 break. v0.15 wins on both axes.

## Decision

Introduce a new `data` verb family that subsumes both `cookie *` and `storage *` operations, gated on a required `--scope` flag. The existing verbs ship in v0.15 as thin aliases that emit a single-line deprecation warning to stderr; they are removed at 1.0.

### Verb name

The recommended verb is **`data`**.

The alternatives considered (see "Verb-name alternatives considered" below) all fall short on either clarity or commitment. `data` is short, accurate (cookies and web storage are both browser-side persistent data), and reads cleanly in both CLI and wire form: `browserctl data get <page> <key> --scope cookies` and `data_get(page, key, scope: :cookies)`.

**Patrick signs off on the verb name before PR 2 opens.** This ADR does not lock the name; merging this ADR with `Status: Accepted` does.

### Scope flag

Every `data` operation requires `--scope {cookies|localStorage|sessionStorage}`. The flag is required, not defaulted: defaulting would re-introduce the ambiguity the consolidation is meant to remove. Invalid scope returns the existing `INVALID_ARGUMENT` typed error from ADR-0020.

The scope names match the browser-platform names (`localStorage`, `sessionStorage`) rather than the current short forms (`local`, `session`) because the long forms are unambiguous to first-touch users and to AI agents that have read MDN. The short forms are accepted as aliases on the wire for v0.15 only, deprecated alongside the old verbs.

### Deprecation path

`cookie *` and `storage *` ship in v0.15 as alias dispatchers that:

1. Translate the call into the equivalent `data` invocation.
2. Emit exactly one warning line to stderr: `warning: 'cookie set' is deprecated; use 'data set --scope cookies'. Removed at 1.0.`
3. **Suppress the warning when the CLI runs under `--output json`** — JSON consumers (AI agents, scripts) do not want non-JSON noise on stderr breaking their parser.
4. Are removed entirely at the 1.0 cut (tracked in `docs/plans/v0.15-lock.md` WS-1 PR 3).

The implementation PR must carry `Release-As: 0.15.0` in its commit footer so release-please does not interpret the `BREAKING CHANGE:` as a 1.0 bump. v0.15 is still pre-1.0; the lock comes after the soak, not at this PR.

## Verb-name alternatives considered

| Candidate | Verdict | Why |
|---|---|---|
| **`data`** | **Recommended** | Accurate, short, reads naturally for both CLI and wire. Pairs with `--scope` cleanly. |
| `resource` | Rejected | Vague. "Resource" in a browser context already means HTTP responses (DevTools' Resource panel); reusing the term invites confusion with `navigation` / `observation` handlers. |
| `kv` | Rejected | Too low-level. Cookies have attributes (domain, path, httpOnly, secure, expires) that don't fit a flat key/value model, and surfacing them under `kv` misleads callers. |
| `cookie` and `storage` left as-is | Rejected | This is the v2.0-deferral path. Locks the duplication into the v1.x line for the duration of soak plus the 1.x major. Defeats the point of v0.15. |

## Operations

Each `data` operation maps to existing cookie and storage entry points. The mapping is mechanical; no behaviour changes beyond the unified envelope and the scope flag.

| `data` op | Cookies (`--scope cookies`) | localStorage (`--scope localStorage`) | sessionStorage (`--scope sessionStorage`) |
|---|---|---|---|
| `data get` | n/a — cookies expose a list, not single-key lookup. Aliased to `data list` with a warning, or rejected as `INVALID_ARGUMENT` (TBD in PR 2). | `storage_get` with `store: "local"` | `storage_get` with `store: "session"` |
| `data set` | `set_cookie` (requires `--domain`, optional `--path`) | `storage_set` with `store: "local"` | `storage_set` with `store: "session"` |
| `data delete` | `delete_cookies` (clears all) | `storage_delete` with `stores: "local"` | `storage_delete` with `stores: "session"` |
| `data list` | `cookies` (returns full array) | `storage_export` with `stores: "local"` (in-memory variant — no `--out`) | `storage_export` with `stores: "session"` |
| `data export` | `export_cookies` (writes file) | `storage_export` with `stores: "local"` | `storage_export` with `stores: "session"` |
| `data import` | `import_cookies` | `storage_import` (localStorage only — `sessionStorage` is tab-scoped, not restorable) | rejected as `INVALID_ARGUMENT` (sessionStorage is not restorable) |

The plan scopes the implementation to `get / set / delete / list`. `export` and `import` are listed for completeness — PR 2 can land them in the same change or punt them to a follow-up at Patrick's discretion. The ADR's recommendation is to land all six together so the surface is consistent on day one.

Scope/operation combinations that have no meaning in the underlying platform (e.g. `data import --scope sessionStorage`) return `INVALID_ARGUMENT` with a clear message rather than silently no-op.

## Response shape unification

The two families diverge in response shape today:

| Op | Today (cookies) | Today (storage) | Diverges on |
|---|---|---|---|
| list | `{ ok: true, cookies: [{...}, ...] }` | `{ ok: true, path: "...", key_count: N }` (export form) | top-level key (`cookies` vs `path`+`key_count`), no in-memory list for storage |
| get | n/a | `{ ok: true, value: "..." }` | only storage has a single-value form |
| set | `{ ok: true }` | `{ ok: true }` | aligned |
| delete | `{ ok: true }` | `{ ok: true }` | aligned |
| import | `{ ok: true, count: N }` | `{ ok: true, origins: N, key_count: M }` | field names (`count` vs `origins`+`key_count`) |

The proposed unified shape:

```jsonc
// data get
{ "ok": true, "scope": "localStorage", "key": "<k>", "value": "<v>" }

// data list
{ "ok": true, "scope": "cookies", "entries": [ { /* scope-typed entry */ } ], "count": 12 }

// data set
{ "ok": true, "scope": "cookies", "key": "<name>" }

// data delete
{ "ok": true, "scope": "cookies", "deleted": 12 }

// data import
{ "ok": true, "scope": "localStorage", "imported": 47 }

// data export
{ "ok": true, "scope": "cookies", "path": "/abs/path.json", "count": 12 }
```

Common envelope fields across every op: `ok`, `scope`. Per-op fields: a single canonical count field (`count` for "items in this response", `deleted` / `imported` for mutation totals — never both `origins` and `key_count`). The per-entry shape inside `entries` differs by scope (cookies carry domain/path/httpOnly/secure/expires; storage entries carry only `key` and `value`); that divergence is real and not hidden.

The lock-file work in WS-3 PR 6 codifies these shapes once PR 2 lands.

## Deprecation window

| Milestone | State of `cookie *` / `storage *` |
|---|---|
| v0.14 (current) | Sole API. |
| v0.15 (PR 2) | Aliases that delegate to `data`, emit a deprecation warning on stderr (suppressed under `--output json`), and stay covered by integration tests. `Release-As: 0.15.0` required in the implementation commit so release-please does not bump to 1.0. |
| v0.15 soak (two months) | Aliases still ship. No further changes. |
| 1.0 cut (WS-1 PR 3, deferred to `docs/plans/v1.0-cut.md`) | Aliases and warning lines removed. Only `data` remains. |

The soak window is the period during which users migrate. Aliases mean a user upgrading from v0.14 to v0.15 sees a warning but their scripts keep working. A user upgrading from v0.15 to 1.0 sees a hard break, but the break has been advertised for two months in stderr, in `docs/reference/api-stability.md`, and in the changelog.

## Consequences

- **One breaking change in the v0.15 milestone, by design.** The plan budgets exactly one `feat!:`; this ADR justifies its use.
- **Lock-file expansion.** WS-3 PR 6 has to cover the `data` verb's response shapes in `spec/fixtures/public_surface.yml`. The unified shape above is the input to that work.
- **Documentation churn.** `docs/reference/commands.md` gains a `data` section; `docs/reference/api-stability.md` loses the "deferred to v2.0" note in favour of a "Removed at 1.0" entry. Both are PR 2's responsibility.
- **Workflow DSL.** The Ruby DSL surface (`Browserctl::Client#cookies`, `#set_cookie`, etc.) gains `#data_get` / `#data_set` / `#data_delete` / `#data_list`. The old methods stay as aliases on the client for the deprecation window — same lifecycle as the wire verbs.

## Open questions for sign-off

1. Verb name: **`data`** as recommended, or one of the alternatives?
2. Scope short forms (`local`, `session`): accept as wire aliases in v0.15, or hard-cut at the rename?
3. `data export` / `data import`: land in PR 2 or follow-up?

---

**Patrick signs off on verb name before PR 2 opens.**

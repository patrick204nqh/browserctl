# ADR-0015: `auth_required` Detection — Signals, False Positives, Pluggability

**Date**: 2026-05-09
**Status**: accepted
**Extends**: ADR-0009 (uniform error shape — AUTH_REQUIRED is a structured code, not a free-form error). Sits next to the existing `Detectors.cloudflare?` from v0.8.
**Deciders**: Patrick

## Context

v0.10's auto-rotate loop (`load_state` → AUTH_REQUIRED → invoke flow → save → continue) needs a reliable signal that the current page is no longer authenticated. The signal has to fire in two places:

1. **Server-side**, during `state load`, before applying cookies. The daemon decides whether to short-circuit with AUTH_REQUIRED based on the bundle's payload (cookies + manifest), without navigating.
2. **Client-side**, after a workflow has navigated, to catch sessions that look valid on disk but are invalidated by the server (server-side logout, JWT expiry).

A single detector callable from both contexts is required.

## Decision

`Browserctl::Detectors::AuthRequired` — a pure module returning a structured `Result`. Three independent signals, evaluated in order, first hit wins.

### Three signals

1. **URL → login path.** Page is currently sitting on `/login`, `/signin`, `/sign-in`, `/auth/login`, `/auth/signin`, or `/account/login`. Catches redirect-based "you're not logged in" responses. Regex matches the canonical paths most apps use.
2. **Recent HTTP 401/403.** The most recent network response on the current page is an auth challenge from the backend. Caller supplies recent responses from page traffic instrumentation; empty list skips this check (callers without traffic capture still get URL + cookie checks).
3. **Cookie ledger.** A caller-supplied list of `{ name:, expires: }` contains entries that are already expired. Used by the daemon's `state load` preflight against the bundle's payload cookies — the only signal that fires before navigation.

Each check is pure. No daemon dependencies. The same module runs server-side (`handlers/state.rb` preflight) and client-side (`workflow.rb` `load_state` hook).

### Result shape

```ruby
Result.new(
  triggered:      Boolean,
  code:           "AUTH_REQUIRED" | nil,
  reason:         "url_login_path" | "http_401_403" | "cookie_expired" | nil,
  suggested_flow: String | nil
)
```

Negative results carry `triggered: false`; positive results carry the discriminator and optional `suggested_flow` populated from the bundle manifest. The shape mirrors `Detectors.cloudflare?` so callers can swap detectors without restructuring the response handling.

### Pluggability

`Browserctl::Detectors` is a module namespace, not a registry. New detectors register by adding a module function — same pattern as `cloudflare?`. The auto-rotate path explicitly calls `Detectors::AuthRequired.detect(...)` rather than iterating over registered detectors, because:

- The auto-rotate handler needs to know the **specific signal** (AUTH_REQUIRED vs cloudflare vs custom), so a single "is anything wrong?" iterator would lose information.
- Detectors have different signatures: `cloudflare?` needs the page; `auth_required` also needs cookies and recent responses. Forcing a uniform signature would push optionality into every detector.
- Order matters: cloudflare must be detected *before* auth_required (a cloudflare interstitial often redirects to a login-looking URL). The handler enforces this order explicitly.

For third-party detectors, the recommended path is the same as third-party secret resolvers — register in `~/.browserctl/detectors.rb`, add a check call in the handler. We are **not** introducing a "detector chain" abstraction in v0.10 because there are only two detectors and the order/signature differences argue against premature uniformity. ADR revisit when the third detector lands.

### False-positive handling

The three signals each have a known false-positive class:

| Signal | False positive | Mitigation |
|---|---|---|
| URL login path | Marketing pages at `/login` (e.g. a sign-up flow that doesn't require auth to view) | Cookie expiry check runs in parallel — bundles with valid cookies won't trigger auto-rotate even if URL matches. The detector still fires (correctly) on the URL, but auto-rotate is gated on the broader workflow context. |
| HTTP 401/403 | API endpoints that intentionally return 403 for unauthorised actions on a fully-authenticated session | `recent_responses` is supplied by the caller — workflow authors who don't want this signal omit it. Auto-rotate uses it only for the page's primary navigation response. |
| Cookie expiry | Session cookie still valid, but a tracking cookie expired | Caller filters to *session-relevant* cookies before passing them in. The `state load` preflight uses the bundle's manifest cookies, which are already scoped to the producing flow's origins. |

False negatives are accepted as the cheaper failure mode: if AUTH_REQUIRED doesn't fire when it should, the workflow proceeds and fails on its own assertions, which the user can see and react to. A false positive that triggers an auto-rotate is more expensive — it runs a flow unnecessarily, possibly prompting for a 2FA code.

The detector defaults to **conservative**: each individual check is tightly scoped, and signals combine via OR but the auto-rotate path only fires when both (a) the bundle has a bound flow and (b) the detector triggers. Bundles with no `flow` in the manifest never auto-rotate even if the detector would have fired.

## Alternatives Considered

### Single regex over the page HTML
- **Pros**: One signal, one check.
- **Cons**: HTML is the noisiest, most brittle surface. Login forms differ wildly. Requires DOM access on every navigate.
- **Why not**: URL + HTTP status + cookie expiry are all cheap and structured; HTML scraping is the last resort.

### Detector chain abstraction
- **Pros**: Symmetric registration; future-proof.
- **Cons**: Two detectors with different signatures; the chain would have to either accept a union of all signatures or force the lowest common denominator.
- **Why not**: Premature abstraction. Revisit when the third detector lands.

### Server-side only
- **Pros**: Single call site.
- **Cons**: Server-side `state load` preflight only sees the bundle, not the live page. Server-side logout (cookies still present, but server-revoked) goes undetected.
- **Why not**: Need both call sites for the auto-rotate guarantee.

### Client-side only (in-workflow)
- **Pros**: Simpler daemon.
- **Cons**: Every workflow author has to invoke the detector manually; the `load_state` ergonomic win disappears.
- **Why not**: The whole point of v0.10 auto-rotate is that the loop is invisible to workflow authors.

## Consequences

### Positive

- One module, two call sites, structured `Result` everywhere.
- Auto-rotate has a clean preflight that runs before any navigation, so an expired bundle doesn't even apply its cookies.
- New auth-related signals slot in without restructuring (add a `check_*` method, OR it into `detect`).
- `AUTH_REQUIRED` exit code 7 + `suggested_flow` give CLI-only callers (Claude agents, shell scripts) the same recovery path as in-process workflows.

### Negative

- Three signals means three places to keep tuned. Login-path regex is the most likely source of drift; smoke specs cover the canonical six (`/login`, `/signin`, `/sign-in`, `/auth/login`, `/auth/signin`, `/account/login`).
- Order-dependence with `cloudflare?` is implicit (handler-enforced), not enforced by the detector module itself.

### Risks

- **Sites with custom login URLs** (e.g. `/access`, `/portal`) will not trigger the URL signal. Cookie-expiry and HTTP signals should still fire; if they don't, the workflow fails on its own assertions and the user can add a custom detector.
- **HTTP 401 response on `/api/health`** (non-load-bearing endpoint) could trigger AUTH_REQUIRED on the wrong page. Mitigation: callers feed only the page's primary navigation responses, not every XHR.
- **Detector module growth**: as we add `paywall_required`, `rate_limited`, etc., the order-dependence problem from this ADR will become a real chain abstraction problem. Tracked as future work.

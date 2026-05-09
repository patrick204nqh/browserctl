# ADR-0013: Flow DSL — Separate Registry, Lifetime, and Stdlib Split

**Date**: 2026-05-09
**Status**: accepted
**Extends**: ADR-0005 (Ruby DSL for workflows). Flows are a sibling concept, not a replacement.
**Deciders**: Patrick

## Context

v0.10 introduces *flows* — small, parameterised, secret-aware sequences whose job is to put the browser into an authenticated (or otherwise gated) state. The need came from three pain points in v0.8/v0.9:

1. Login was duplicated in every workflow that touched a service.
2. `load_session(name, fallback: "...")` solved the recovery loop but tied recovery to a workflow file the caller had to write and maintain.
3. There was no shared place for stdlib auth surfaces (TOTP, magic link, Google/GitHub OAuth, Cloudflare).

A flow is just "the smallest replayable thing that produces a usable browser state". Workflows are "the script that does the actual job after that state exists". Treating them as the same primitive would make either too small to be useful or too big to be reusable.

## Decision

Add `Browserctl::Flow` and `Browserctl::FlowRegistry` as a separate first-class concept living next to workflows.

### A separate registry from workflows

`FlowRegistry` and `WorkflowRegistry` are two different stores with two different search paths. A flow is *not* a workflow with a different filename.

Reasons:

- **Different purpose, different signature.** Flows return *state* (cookies + storage + manifest); workflows return *task completion*. Mixing them in one registry would force one signature to dominate.
- **Different lifetime.** A flow runs to produce a bundle, then exits. A workflow runs the user's script. The auto-rotate path (`load_state` → AUTH_REQUIRED → invoke flow → save → continue) needs a registry it can look up by short name without colliding with a workflow that happens to be named `github_login`.
- **Different invocation surface.** Flows are invocable from CLI (`browserctl flow run`), from inside workflows (`invoke :flow_name`), and from the daemon's auto-rotate path. Workflows are invoked from CLI and `compose`/`invoke`. Sharing the registry would require disambiguation rules at every call site.
- **Stdlib only makes sense for flows.** A "stdlib workflow" has no meaning — workflows are user-specific scripts. A "stdlib flow" (TOTP, OAuth) is something every project benefits from.

### Lifetime semantics

A flow's lifetime is bounded by `Flow#run(params)`:

- `precondition` block runs first; raises `FlowPreconditionFailed` to short-circuit before any browser action.
- `step` blocks run in order; each carries optional `retry_count:` and `timeout:` matching the workflow DSL.
- `produces_state` block (optional) runs last and tells the daemon what origins were touched during the flow — used as the default `origins[]` in the bundle manifest unless the caller passes `--origins`.
- `postcondition` block validates the resulting browser state; failure raises `FlowPostconditionFailed`.

There is no per-step state shared across runs. A flow that needs intermediate values uses local variables in its `Flow#run` closure; cross-flow state goes through `state save`/`state load`.

### Stdlib gem-split trigger

Stdlib flows ship in the core `browserctl` gem until **either** of:

1. Flow count exceeds ~10. Six ship in v0.10 (`totp_2fa`, `basic_auth`, `magic_link_email`, `oauth_google`, `oauth_github`, `cloudflare_solve`). Room for ~4 more before the threshold.
2. A flow needs a heavy optional dependency the core gem should not require (e.g. an IMAP client for email-based magic links beyond the current minimal implementation).

When triggered, stdlib flows move to a new gem `browserctl-flows-stdlib`. The core gem keeps the registry and search-path logic; the stdlib gem only provides flow files. Each stdlib flow declares `min_browserctl_version` in its DSL header so a future split can reject mismatched cores cleanly.

### Versioning runtime check

Each flow declares `version "X.Y.Z"`. When a bundle's manifest names a flow:

- **Patch mismatch** — silently accepted.
- **Minor mismatch** — warn on stderr, run.
- **Major mismatch** — refuse; CLI `--force` overrides; no workflow-level override (the auto-rotate path will surface AUTH_REQUIRED instead).
- **No `flow_version` in manifest** (pre-v0.10 imports) — warn once, accept.

This is a runtime check on the consuming side, not a registry-level filter. A flow at v2.0.0 still loads — the check fires only when paired with an old bundle.

## Alternatives Considered

### One registry, "kind:" tag on each entry
- **Pros**: Single search path; one `list` command.
- **Cons**: Forces every call site to filter; defeats the point of the separation.
- **Why not**: The two kinds have different invocation contracts; merging them creates ambiguity at every lookup.

### Flows as workflows with a `produces_state` flag
- **Pros**: Reuses the workflow DSL verbatim.
- **Cons**: Workflows can have multiple steps that return values, share state across `compose`, and persist across invocations. Flows are meant to be small, atomic, and side-effect-on-browser-only. Conflating them would push workflow complexity into stdlib auth files.
- **Why not**: The two have different shapes. A flow is a function returning state; a workflow is a procedure with side effects.

### Inline flows in workflow files
- **Pros**: No new file type.
- **Cons**: No reuse across projects; no stdlib; `state rotate` has nothing to invoke.
- **Why not**: Reusability across projects (and from the daemon's rotate path) is the whole reason flows exist.

### Ship stdlib as a separate gem from day one
- **Pros**: Cleaner dependency surface.
- **Cons**: Six small files don't justify a release pipeline split; users with only `browserctl` installed would have a worse onboarding experience.
- **Why not**: The split is cheap to do later; doing it early is a sunk cost on every release.

## Consequences

### Positive

- Auto-rotate (`load_state` → AUTH_REQUIRED → invoke bound flow) has a clean lookup target.
- Stdlib auth surfaces are shared across projects without copying.
- `flow run` works as a standalone CLI verb for one-off authenticated sessions, independent of any workflow.
- Versioning at the flow level (not the gem level) lets users pin a specific flow without pinning browserctl.

### Negative

- Two registries, two search paths, two `list`/`describe` command pairs. Surface area grows.
- Flow-vs-workflow distinction is an extra concept newcomers have to learn — addressed by `docs/concepts/flows.md`.

### Risks

- **Boundary erosion**: someone adds branching/state to a flow, turning it into a workflow-with-extra-steps. Mitigated by keeping the DSL deliberately smaller than the workflow DSL (no `compose`, no `store`/`fetch`) and by code review.
- **Stdlib bitrot**: bundled flows can break when target sites change their login UI. Mitigated by smoke specs per stdlib flow and by versioning — bundles produced with a known-good flow version stay consumable until the user explicitly rotates.

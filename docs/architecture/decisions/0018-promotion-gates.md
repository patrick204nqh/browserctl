# ADR-0018: Promotion Gates — N Successful Runs, `--force`, Disqualifications

**Date**: 2026-05-10
**Status**: accepted
**Pairs with**: ADR-0016 (stable refs), ADR-0017 (fingerprint algorithm). Promotion is the moment a workflow becomes "real" — globally invocable, callable from other workflows, optionally wrapped as a flow.
**Deciders**: Patrick

## Context

v0.11's pipeline turns recordings into promoted, replayable artefacts:

```
recording start → recording stop → workflow generate → workflow run --check (× N) → workflow promote
```

The generator emits a workflow file from a single recording. That file may pass `--check` once and break the next time — a single clean run is not enough evidence that the workflow is durable. We need a gate that promotes only workflows whose `--check` history shows reliable behaviour.

The gate has to be cheap to operate (no separate CI), interpretable (a developer can see why a workflow is or isn't promotable), and overridable (sometimes you need to ship a workflow you know works despite the report saying otherwise).

## Decision

Promotion is gated by an append-only check ledger that records every `--check` run's verdict. Implementation: `lib/browserctl/workflow/promotion_ledger.rb`, `lib/browserctl/workflow/promoter.rb`.

### Ledger

`~/.browserctl/check_ledger.jsonl` — one JSONL line per check run:

```json
{"ts": "2026-05-10T12:00:00Z", "workflow": "scrape_issues", "verdict": "clean"}
```

Verdicts mirror the runner's three outcomes from ADR-0017's drift contract:

- `clean` — every step passed, no drift events recorded.
- `drift` — every step passed, but at least one fingerprint rematch occurred *or* a snapshot diff was non-empty.
- `fail` — a step raised.

The ledger is append-only and per-user (not per-project). Switching projects or branches does not reset history; deleting the file does. There is no rotation; the file grows linearly with check runs and is JSONL so it can be inspected with `tail` / `jq`.

### Gate: N consecutive `:clean` runs

`workflow promote <name>` is allowed iff the workflow's *trailing streak* of `:clean` verdicts is `>= threshold` (default 3). A `:drift` or `:fail` resets the streak.

> **Trailing streak**, not cumulative count. A workflow that has 50 clean runs followed by one drift run has a streak of 0 and is not promotable. The point of the gate is "the workflow is reliable *now*," not "was reliable at some point."

### Why N = 3

- **N = 1** is too lax. A single clean run is consistent with a happy-path replay against an unchanged page; it gives no signal about robustness.
- **N = 5+** is too strict. A workflow on a moderately-flaky page may never accumulate 5 in a row even when it works correctly most of the time, and the agent loop runs out of patience.
- **N = 3** matches "informal QA." If you can replay the workflow three times in a row without seeing drift, you have evidence that the page is stable enough to bind a workflow to.

The threshold is configurable per-promote (`--threshold N`) so a project can dial it up for high-stakes workflows or down for smoke-test workflows. The default is the value that should ship with no flag.

### Why `:drift` resets the streak

A drift event is *successful behaviour*, but it is also *evidence that the page is moving*. Promotion is the moment we lock the workflow file in as the canonical version. Locking in a version that just experienced cosmetic drift is choosing to bake the drift into the workflow. The streak reset forces the user to either:

1. Accept the drift as the new normal — let it run clean three times in a row (the fingerprint rematches are by then producing a stable view), then promote.
2. Update the workflow file to match the new selectors or fingerprints, then re-check.

Either path produces a more durable artefact than promoting on a drift run.

`--force` exists for the case where the user knows the drift is benign and is willing to ship anyway.

### Why `--force` exists

The gate is opinionated, but it is not a security boundary. A user who has read the drift report and decided "yes, this is fine, ship it" should not be forced to fake clean runs to land their work. `--force` makes the override explicit and visible: the resulting promote response includes `forced: true`, so anyone reading the JSON output can tell the gate was bypassed.

What `--force` does **not** do:

- Skip recording the verdict in the ledger. The history remains accurate.
- Skip the file-not-found check. A force-promote of a non-existent workflow still errors.
- Promote a workflow that doesn't exist in the project source dir.

### What disqualifies a workflow

The gate checks the streak. It does **not** check:

- Workflow content (we don't lint generated Ruby).
- Whether the workflow's params resolve at runtime.
- Whether the page targeted is still online.
- Whether secrets are wired up correctly (`secret: true` placeholders are valid until used).

These are runtime concerns and would couple promotion to network state. The gate is a binary decision based on observable replay history; everything else is the user's call.

There is also no concept of "expired clean runs." A streak from a year ago is as good as a streak from yesterday. Recordings against pages that have since changed will produce drift on the next check, and the streak resets naturally. We do not invent a TTL because the operational signal already exists.

### `--as-flow` and the promotion contract

When `--as-flow` is set, after the gate passes and the workflow file is copied, a flow wrapper is generated alongside (`~/.browserctl/flows/<name>.rb`). This is mechanically a separate step but conceptually part of the same promotion: we are saying "this workflow is reliable enough to be a globally-callable flow." The wrapper introduces no additional gates — if the workflow is promotable, it is wrappable.

## Alternatives Considered

### Cumulative count instead of trailing streak
- **Pros**: Workflows accumulate evidence over time; transient drift doesn't penalise a long-running workflow.
- **Cons**: The signal we want is "reliable *now*," not "was reliable historically." A workflow with 100 clean runs and one recent drift is in exactly the state we don't want to lock in.
- **Why not**: Trailing streak captures recency without bookkeeping.

### CI integration: gate on a green build
- **Pros**: Familiar model; exposes promotion to existing pipelines.
- **Cons**: browserctl runs locally against live pages by design. Pulling promotion into CI requires either (a) running real browser automation in CI (slow, flaky, expensive), or (b) recording-replay infrastructure (complex). The local ledger achieves the same goal for the workflow's actual environment.
- **Why not**: The local environment *is* the test environment. Adding CI doesn't make the signal stronger here.

### Configurable per-workflow threshold via a header comment
- **Pros**: Different workflows have different reliability needs.
- **Cons**: Couples the workflow file to its promotion policy; surface area we can't take back.
- **Why not yet**: Open question deferred. `--threshold` on the CLI covers the same need without persisting policy in the workflow file. If repeated need emerges, a `# @promotion_threshold 5` directive can be added without breaking existing files.

### No gate; promote is just a copy command
- **Pros**: Maximally simple. Trust the user.
- **Cons**: The pipeline asks the user to record once and promote later. Without a gate, the user is the only thing standing between "I just made a recording" and "this is now my canonical workflow." The gate makes the implicit acceptance criterion explicit and observable.
- **Why not**: The whole reason `--check` exists is to produce evidence; throwing the evidence away at promote-time wastes the work.

### Reset the streak on `:fail` only, not `:drift`
- **Pros**: Drift is "still passing"; not penalising it would let workflows promote through cosmetic churn.
- **Cons**: Promoting on drift bakes the cosmetic state into the canonical workflow. The next replay will likely drift again — the workflow has now codified the drift, not absorbed it.
- **Why not**: Drift is signal that the page is moving. Promotion should happen from a stable view of the page, not a moving one. The `--force` escape hatch covers the "I know what I'm doing" case.

## Consequences

### Positive

- Promotion is evidence-driven and the evidence is inspectable (`tail ~/.browserctl/check_ledger.jsonl`).
- The gate aligns naturally with the agent loop: an AI agent that runs `--check` until clean and then promotes is doing the right thing without any extra reasoning.
- `--force` keeps the gate from being adversarial. Users retain agency.
- The ledger is also a passive observability tool: how often does this workflow drift? when did it start drifting? — the answers are in the file.

### Negative

- The ledger is per-user, so a CI machine and a developer's laptop have independent histories. A workflow promoted on the developer's laptop is not "automatically promotable" on CI. Acceptable: promotion is a deliberate act, and the history follows the actor doing the deliberating.
- New users meet the gate immediately. The first time someone runs `workflow promote`, they get an "ineligible" message because the streak is 0. The error message tells them what to run; the friction is intentional but real.

### Risks

- **Ledger corruption.** If the JSONL file is truncated or has a malformed line, the streak query skips the bad line rather than aborting. Trade-off accepted for robustness over strictness — a corrupted line should not lock a user out of promoting.
- **Streak gaming.** A user could `tail` then `head` the file to fake a streak. We are not defending against this; the user owns their own ledger and `--force` is the documented escape hatch. The gate is a hint, not an enforcement boundary.
- **Threshold drift.** If 3 turns out to be wrong (too lax in practice; too strict in agent loops), we'll change it. The default is encoded in `PromotionLedger::DEFAULT_THRESHOLD` and is a single point of change.

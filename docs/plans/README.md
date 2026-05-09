# Execution plans

Per-milestone PR-sized breakdowns. Strategy lives in `../vision.md`; this directory is how we run it.

| Plan | Theme | Status |
|------|-------|--------|
| [v0.10 — Flows](v0.10-flows.md) | Reusable flow DSL, unified `state`, auth re-detection | Not started |
| [v0.11 — Replayable](v0.11-replayable.md) | Stable refs, fingerprint self-healing, recording → workflow → flow pipeline | Blocked on v0.10 |
| [v0.12 — Solid](v0.12-solid.md) | Versioned formats, error model, observability, test pyramid, perf budgets | Blocked on v0.11 |

Each plan file follows the same shape: goal · non-goals · dependencies · workstreams (each = a stack of PRs with file paths and acceptance criteria) · ADRs to write · breaking changes log · milestone acceptance · open questions · sequencing diagram.

When a milestone closes:
1. Tick the "done" checklist in its plan file.
2. Move the strategy entry in `../vision.md` from `[ ]` to `✓ _(shipped)_`.
3. Leave the plan file in place as historical record.

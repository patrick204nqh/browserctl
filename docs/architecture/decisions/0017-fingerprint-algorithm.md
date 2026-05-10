# ADR-0017: Fingerprint Algorithm — Signal Selection, Weighting, Threshold Defaults

**Date**: 2026-05-10
**Status**: accepted
**Pairs with**: ADR-0016 (stable refs are the fast path; fingerprints are the recovery path).
**Deciders**: Patrick

## Context

Even with stable refs (ADR-0016), a recorded workflow can encounter an element whose ref has changed between recording and replay. Real causes: a renamed accessible name, a refactored parent chain, a redesign that re-shuffled headings. The ref doesn't resolve, and the workflow either fails or — worse — fails silently if the test only checks for "no exception."

The fingerprint system is the recovery path. Each interacted element ships a fingerprint at recording time. At replay, when a ref or selector misses, the matcher scores live snapshot elements against the recorded fingerprint and picks the best above a threshold. Implementation: `lib/browserctl/replay/fingerprint_matcher.rb`, `lib/browserctl/snapshot/fingerprint.rb`.

The choice is what signals to include, how to weight them, and where to set the threshold.

## Decision

### Signals

A fingerprint carries four fields, all on the wire as part of the snapshot element record:

```json
{
  "text": "Save changes",
  "role": "button",
  "neighbors": ["form", "Email", "Password", "Save changes", "Forgot password?"],
  "position": { "index": 12, "depth": 4 }
}
```

- **`text`** — visible text content, lowercased and trimmed. The single strongest signal. A user describing "the Save button" almost always means a button whose visible text is "Save" or close to it.
- **`role`** — same role used in ref derivation (ARIA role, explicit or implicit). Catches the "renamed but still a button" case.
- **`neighbors`** — siblings + parent text, as a small array. Captures the *neighbourhood* of the element — what surrounds it on the page. The matcher uses Jaccard similarity, so order doesn't matter and superset/subset relationships score gracefully.
- **`position`** — `{index, depth}` of the element in its parent and in the document. The weakest signal. Used as a tiebreaker; never decisive on its own.

Deliberately excluded:
- **CSS classes / attribute values.** Rotate too freely; including them would re-import the brittleness ADR-0016 worked to remove.
- **Pixel coordinates.** Layout-dependent; useless across viewport changes.
- **Computed styles.** Same problem, plus expensive to capture.

### Weights

```
text       0.40
role       0.20
neighbors  0.25
position   0.15
total      1.00
```

Reasoning: text + role together (0.60) clear the default threshold (0.60). That means a renamed neighbour or a shifted index alone never breaks replay — the canonical "same button, different surroundings" case scores `1.0 × 0.40 + 1.0 × 0.20 = 0.60` minimum and gets through. Conversely, an element with the same text but a different role (e.g. a `<span>` styled as a button replaced by an actual `<button>`) scores `0.40` and falls through, which is the correct outcome — semantically they are different elements.

The weights are exposed via `FingerprintMatcher.new(weights: …)` for tuning, but the defaults are intentional and the public API treats them as stable.

### Threshold default

`DEFAULT_THRESHOLD = 0.6`.

Below this number, the matcher returns no match (the element is treated as gone). The choice is calibrated to:

- Accept the canonical "renamed neighbour" case (text + role match → 0.60).
- Reject "wrong element on the page that happens to share half the signals" (text match alone is 0.40 — below threshold — so a stray element with the same text but different role/neighbors does not get hit).
- Leave headroom for tightening (a workflow can pass `threshold: 0.75` for stricter matches).

We deliberately did **not** adopt a higher default like 0.75. A 0.75 threshold would refuse the very drift case the system exists to absorb (one cosmetic change is enough to drop the score below 0.75 with the current weights), turning fingerprint matching from a recovery path into a noisy "almost passed" signal.

### False-positive bound

Fingerprint matching is allowed to fail silently in two ways:

1. **Match the wrong element.** Two elements share text, role, and most neighbours; the matcher picks the wrong one. Mitigation: `position` is included so when neighbour Jaccard is tied, the closer element wins. Empirically this catches the duplicated-button-in-a-table case unless every neighbour is also identical (in which case the elements are interchangeable).
2. **Match no element above threshold when one exists.** A redesign rewrote everything; the right candidate exists but scores 0.55. Mitigation: the drift report surfaces "no candidate above threshold" as `unresolved`, and the skill teaches agents to re-record on unresolved events.

We accept these failure modes as the price of working at all. The alternative — refuse to fall back unless we're certain — is the v0.10 behaviour we're trying to fix.

### Score is reported, not just thresholded

Every fingerprint match decision lands in the drift report as `{matched_ref, score, reason}`. Agents and humans can see *how confident* the match was, not just whether it passed. A 0.62 rematch reads differently from a 0.92 rematch even though both clear the threshold. The skill (ADR-adjacent docs in `skills/automate/SKILL.md`) explains how to act on score bands.

## Alternatives Considered

### Use a single distance metric (e.g. Levenshtein on a serialised element)
- **Pros**: One number, easy to reason about.
- **Cons**: A renamed CSS class and a renamed accessible name would distort the metric equally, even though one is cosmetic and the other is semantic. The decomposed weighted sum lets us encode "I trust text more than position" as a configurable weight.
- **Why not**: We want the weights *to be visible* — both for tuning and for explaining decisions.

### Use the OS accessibility tree directly
- **Pros**: Pre-computed semantic tree; matches what screen readers see.
- **Cons**: Different across browsers, slower to capture, requires CDP `Accessibility.getFullAXTree` traversal per snapshot. The signals we want (text, role, neighbours) are derivable from the DOM at much lower cost.
- **Why not**: Cost-benefit. We already walk the DOM; computing fingerprints in the same pass is essentially free.

### Train a model
- **Pros**: Could learn weights from real drift cases.
- **Cons**: Model artefact in the gem; dataset to curate; explainability collapses. The space of features (text, role, neighbours, position) is small enough that hand-tuned weights are within a reasonable factor of optimal, and tunable per-workflow if needed.
- **Why not**: Costs outweigh benefit at this scale.

### Per-workflow override stored in the workflow file
- **Pros**: Workflows that sit on stable pages can crank the threshold up; flaky pages can lower it.
- **Cons**: Extra surface area for a feature that we don't have evidence we need yet.
- **Why not yet**: Open question deferred to a future ADR. The `FingerprintMatcher` constructor already accepts `threshold:` and `weights:`, so the runtime hook is in place when we're ready.

## Consequences

### Positive

- Replay survives cosmetic drift (renamed classes, restructured neighbours) without human intervention.
- Drift is observable — the matcher's confidence is reported per event, so failures and near-misses look different in logs.
- Weights and threshold are tunable knobs, not magic constants. Tests can pin specific scoring behaviours.

### Negative

- A drift report on every check run that has *any* drift events. Workflows that ride out cosmetic churn produce noisier ledgers than workflows on stable pages. Acceptable; the report is read-on-demand.
- The matcher is per-element, not per-workflow. We can't say "this workflow is allowed up to 3 unresolved drifts before flagging" — every unresolved event surfaces. Mitigation: the workflow-level verdict (`:clean` / `:drift` / `:fail`) rolls up the events into a single signal that the promotion gate consumes.

### Risks

- **Adversarial pages.** A page that randomises text content on every load (e.g. a captcha or A/B test) defeats fingerprinting by design. The matcher will report `unresolved` and the workflow drops to `:fail`. This is correct — fingerprint matching is for cosmetic drift, not for content the page is intentionally varying.
- **Threshold drift over time.** As we encounter real-world drift cases, the right default may shift. The current default is anchored in the weighting model: as long as text + role = threshold, the canonical case works. Future weight changes must preserve this invariant or pick a new one.

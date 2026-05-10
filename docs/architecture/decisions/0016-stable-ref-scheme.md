# ADR-0016: Stable Ref Scheme — Hash Inputs, Collision Handling, Replace-Don't-Version

**Date**: 2026-05-10
**Status**: accepted
**Supersedes**: the v0.2–v0.10 incrementing-counter ref scheme from `Snapshot::Builder`.
**Related**: ADR-0006 (snapshot format), ADR-0017 (fingerprint algorithm — fingerprints are the *fallback* when refs alone aren't enough).
**Deciders**: Patrick

## Context

Through v0.10, every snapshot assigned refs by walking the DOM in order and emitting `e1`, `e2`, `e3`, ... The refs were stable *within a single snapshot* but had no relationship across snapshots. Two snapshots of the same page taken seconds apart produced refs in arbitrary order whenever the DOM walked differently — a single inserted node could shift every subsequent ref by one.

That was acceptable when a snapshot was always paired with an action in the same turn. v0.11 changes the contract: recorded workflows replay against snapshots taken at a different time, and possibly a different rendering of the same page. A ref captured during recording (`e3`) had no chance of pointing at the same element on replay.

We need refs that are deterministic functions of the element, not of its enumeration order.

## Decision

Refs are derived from a hash of four element signals. Implementation: `lib/browserctl/snapshot/ref.rb`.

### Hash inputs

```
ref = "e" || hex(SHA-256(role || "|" || accessible_name || "|" || tag || "|" || parent_path))[0, 7]
```

Each component:

- **`role`** — explicit `@role` if present, otherwise an implicit role from the tag (`a` → `link`, `button` → `button`, `input` → `textbox`, `select` → `combobox`, `textarea` → `textbox`), otherwise the tag name itself. This collapses semantically-equivalent variants (`<a role="button">` and `<button>` both score `role=button`).
- **`accessible_name`** — first non-empty of `aria-label`, `placeholder`, `alt`, `title`, then trimmed text content (truncated at 80 chars). Mirrors the AT name resolution algorithm rather than reinventing one.
- **`tag`** — the tag name. Distinguishes elements that share a role but render differently (`<a>` vs `<button>`).
- **`parent_path`** — chain of ancestor tag names from the element up to `<html>`, joined with `>`. Two `<button>Save</button>` elements in different forms get different refs.

The hash is SHA-256 truncated to 7 hex characters (28 bits, ~268M space). Collisions across pages are not a concern because refs are scoped to a single snapshot. Collisions *within* a snapshot — two visually identical elements at the same parent path — are real and handled below.

### Collision handling

Within a snapshot, the deriver records every emitted ref. If a candidate hash collides with one already taken, the deriver appends `-2`, `-3`, ... until unique:

```
e1a2b3c        # first occurrence
e1a2b3c-2      # second occurrence (same role+name+tag+parent_path)
e1a2b3c-3      # third
```

The suffix is *not* part of the hashed identity — it's a within-snapshot tiebreaker. Across two snapshots of the same page, both occurrences re-derive to the same `e1a2b3c` and re-acquire suffixes in the same order, so `e1a2b3c-2` in snapshot A and `e1a2b3c-2` in snapshot B point at the same element as long as both occurrences are still present.

When one of the two collides-elements disappears between snapshots, the surviving one keeps its suffix-free `e1a2b3c`. That's the intended behaviour: the suffixed ref means "the second of N siblings I saw," and the meaning is preserved when N changes.

### Why 7 hex characters

Short enough to type, copy, and read in JSON output without dominating the field. Long enough that within-snapshot collision rate is dominated by *real* element duplication (same role+name+tag+parent), not hash collisions. We expect <100 elements per snapshot on average; collision probability is below `100²/2³⁰ ≈ 0.0001%` per snapshot.

### Replace, don't version

The wire format changes incompatibly. Anything that hard-coded `e1`/`e2` in tests, scripts, or stored recordings breaks. We bump `Browserctl::PROTOCOL_VERSION` so clients can detect, but we do **not** ship a "v1 refs vs v2 refs" toggle.

Reasoning: the old refs are not just renamed — they are derived from a different model (enumeration order vs element identity). A flag that flipped between them would be a permanent maintenance tax to support a model that the rest of v0.11 actively abandons. Recordings produced before v0.11 fall back to selector-only replay (fingerprint metadata is empty for old logs); the recording format change is documented in the migration note.

## Alternatives Considered

### Keep the incrementing counter; rebuild a stable index on the side
- **Pros**: Existing recordings keep working untouched.
- **Cons**: Two-ref world: callers must know which one to use when. Confusing; bug-prone. The "side index" *is* what we'd build the new ref on top of, so we end up shipping both anyway.
- **Why not**: Refs are the user-facing identifier; there should be exactly one.

### Hash the element's full XPath
- **Pros**: Maximally specific — the same XPath is the same element.
- **Cons**: Brittle in exactly the cases where stability matters most. Inserting a `<div>` for layout shifts the XPath of every nephew. The fingerprint system handles cosmetic drift; the ref system shouldn't compete with it.
- **Why not**: We want refs to survive cosmetic changes. Parent path (tag chain only, no positions) is the right granularity.

### Use the element's `id` when present, hash otherwise
- **Pros**: Matches developer intuition — `<button id="save">` deserves a stable ref.
- **Cons**: Half the elements on a typical page have no `id`. The two paths produce visually different refs (`e_save` vs `e1a2b3c`); telling them apart adds cognitive load. The semantic signal (`role + accessible_name`) is usually as stable as a hand-written `id`.
- **Why not**: Uniform format wins. Semantic signals are the right input.

### Hash everything (including class names, attribute values)
- **Pros**: Maximally specific.
- **Cons**: Tutorials and design systems rotate class names freely (`btn-blue-500` → `btn-primary`); refs would change on cosmetic refactors. That's exactly what fingerprint matching is supposed to absorb.
- **Why not**: The ref is the fast path; the fingerprint is the slow recovery. Don't put cosmetic signals in the ref.

## Consequences

### Positive

- Same DOM element gets the same ref across snapshots of the same page.
- Refs are diff-friendly: `git diff` on two snapshot fixtures highlights only the elements that actually changed identity.
- Recorded workflows can address by ref again, not only by selector — the v0.10 "ref-based interactions cannot replay" warning is largely retired (still applies to elements with no semantic signals at all, which are rare).
- The ref encodes the four signals in its derivation, so a divergence between recorded and live refs tells you *why* without further inspection (different role? different accessible name?).

### Negative

- Wire format break. v0.10 fixtures and any external test harnesses asserting on `e1` need updating. Scope is contained because pre-v0.11 refs were already documented as snapshot-local.
- The hash is opaque. `e1a2b3c` doesn't tell a human reading the snapshot what the element is — they need the rest of the JSON record. (The old `e1` was equally opaque, so this is parity, not a regression.)

### Risks

- **Within-snapshot collision storm.** A page with 50 visually-identical "Delete" buttons in the same parent table produces `eXX-2`, `eXX-3`, ... up to `eXX-50`. Refs remain unique but suffixes become a poor key. Mitigation: this is the correct failure mode — when the page itself can't tell elements apart, neither can we, and the fingerprint system is responsible for the recovery via neighbors and position.
- **Accessible-name changes that propagate.** A page rename ("Save" → "Save changes") changes the ref for that element. By design — it's a different element semantically, even if the underlying DOM node is the same. Recorded workflows fall through to fingerprint match, which is exactly what fingerprints exist for.

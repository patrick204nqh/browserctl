# Snapshots and Refs

When an AI agent needs to interact with a page, it has to answer two questions: *what is on this page?* and *how do I refer to a specific element?*

CSS selectors are the traditional answer to the second question. They work well when a human writes them by hand in a test suite they own. They break in three ways when an AI agent generates them at runtime:

- **Fragility.** A selector like `div.auth-form > input:nth-child(2)` breaks whenever a developer refactors the markup, adds a wrapper element, or renames a class.
- **Verbosity.** Selectors are long relative to the information they carry. An agent that echoes selectors back to the model burns tokens on structure rather than semantics.
- **No natural language anchor.** The model has to generate a precise CSS path from the page's HTML. That requires reasoning about DOM structure rather than just identifying the element by what it is.

browserctl uses a different model: **refs** — and as of v0.11, refs are stable across snapshots and every element ships a **fingerprint** that can rematch it after structural drift.

---

## The snapshot

`browserctl snapshot <page>` inspects the live page and returns a compact JSON array of every interactable element — inputs, buttons, links, selects, textareas. Static elements that cannot be acted on are omitted.

```bash
browserctl snapshot login
```

```json
[
  {
    "ref": "e3f9a1b",
    "tag": "input",
    "text": "",
    "selector": "form#login > input#email",
    "attrs": {
      "type": "email",
      "name": "email",
      "placeholder": "you@example.com"
    },
    "fingerprint": {
      "text": "you@example.com",
      "role": "textbox",
      "neighbors": ["label:Email", "input:"],
      "position": { "index": 3, "depth": 4 }
    }
  },
  {
    "ref": "ab12c34",
    "tag": "button",
    "text": "Sign in",
    "selector": "form#login > button",
    "attrs": { "type": "submit" },
    "fingerprint": {
      "text": "Sign in",
      "role": "button",
      "neighbors": ["input:", "a:Forgot password?"],
      "position": { "index": 7, "depth": 4 }
    }
  }
]
```

Each element carries:
- **`ref`** — a stable, hash-prefixed ID derived from the element's semantics (see below)
- **`tag`** — the element type (`input`, `button`, `a`, `select`, etc.)
- **`text`** — visible text or label
- **`selector`** — the CSS selector, included as a fallback
- **`attrs`** — relevant attributes (type, name, placeholder, href, etc.)
- **`fingerprint`** — semantic + neighborhood signals for rematch on replay

The format is intentionally compact. An agent processing a snapshot pays for element count, not DOM depth.

---

## How refs are derived

A ref is `e` + the first 7 hex characters of `sha256(role | accessible_name | tag | parent_path)`:

- **`role`** — explicit `@role` attribute, otherwise the implicit ARIA role for the tag (`button`, `link`, `textbox`, …)
- **`accessible_name`** — `aria-label`, `placeholder`, `alt`, `title`, or visible text — whichever is first non-empty
- **`tag`** — the HTML tag name
- **`parent_path`** — the chain of ancestor tag names up to `<html>`

Two consequences fall out of this:

1. **The same DOM element produces the same ref across snapshots of the same page.** Take a snapshot, take it again — refs are identical. This means a recorded workflow can refer to an element by ref and still resolve it on replay.
2. **Refs are unaffected by class renames, attribute reshuffles, or unrelated subtree changes.** None of those are inputs to the hash.

If two elements have identical inputs and would collide in a single snapshot (e.g. two `<a>Same</a>` siblings), the second gets a `-2` suffix (`-3`, `-4`, …) to keep refs unique within the snapshot. The base hash is preserved.

---

## Ref-based interaction

After a snapshot, use the `ref` values directly for subsequent commands. No selector needed:

```bash
browserctl fill  login --ref e3f9a1b --value me@example.com
browserctl fill  login --ref f81de02 --value s3cr3t
browserctl click login --ref ab12c34
```

An agent workflow looks like this:

```
1. snapshot login                         → receive JSON with refs
2. identify e3f9a1b as the email field    (by tag, accessible name, placeholder)
3. fill login --ref e3f9a1b               → no selector reasoning required
4. click login --ref ab12c34              → submit
5. snapshot login                         → observe the result
```

The model sees semantics, not structure. The selector is there in the JSON if needed, but in practice the ref + metadata is enough to act correctly.

---

## Fingerprints — surviving structural drift

Refs are stable when the *semantic* signature of an element is unchanged. They will move when:

- The element's accessible name changes (`Sign in` → `Log in`).
- The element's role changes (`<a>` becomes `<button>`).
- An ancestor element is added or removed, changing the parent path.

When refs move, replay needs another way to find the element. Every entry's `fingerprint` field is the rematch signal:

```json
"fingerprint": {
  "text":      "Sign in",
  "role":      "button",
  "neighbors": ["input:", "a:Forgot password?"],
  "position":  { "index": 7, "depth": 4 }
}
```

- **`text`** — accessible name (capped at 80 chars)
- **`role`** — same role logic as the ref hash
- **`neighbors`** — short `tag:text` signals for siblings within radius 2, ignoring whitespace text nodes
- **`position`** — `index` in parent + DOM `depth`

The replay layer scores candidate elements in the new DOM against this fingerprint and picks the best match above a threshold. Drift is logged but doesn't break the run. The full mechanics — scoring, threshold, drift reporting — live in [Replay and self-healing](replay-and-self-healing.md) once that workstream lands.

---

## Diff snapshots

After the first snapshot, subsequent snapshots can return only the elements that changed since the last one:

```bash
browserctl snapshot login --diff
```

This is useful in two situations:

**Async updates.** After clicking a button that triggers an API call, `snapshot --diff` tells you exactly which elements appeared or changed — a loading spinner becoming a success message, a table row added, a disabled button becoming enabled. You don't have to diff the full page yourself.

**Token efficiency.** If the page has 80 elements and only 3 changed after an action, there's no reason to re-read all 80. The diff surfaces just the signal.

---

## Refs and recording

When you record a session with `browserctl record start <name>`, each command is captured and later replayed as a workflow. Selector-based interactions replay directly. Ref-based interactions now replay through two layers:

1. The recorded ref is looked up against the current snapshot. Because refs are stable, this works whenever the page is semantically unchanged.
2. If the ref no longer resolves (e.g. the page was redesigned and the parent path shifted), the recorded **fingerprint** is matched against the new DOM. If a match scores above the threshold, replay continues silently and the rematch is logged.

Workflow generation (v0.11) prefers stable selectors, with the fingerprint shipped as an inline comment for human review.

---

## HTML format

When a model needs to understand page structure rather than interact with specific elements, pass `--format html`:

```bash
browserctl snapshot login --format html
```

This returns the full page HTML. Useful for reading content, understanding layout, or extracting information. For interaction, use the default JSON format.

---

## Cloudflare challenge signals

Both `snapshot` and `navigate` include a `challenge` field in their response when a Cloudflare interstitial is detected on the page:

```json
{ "challenge": true, ... }
```

This is the entry point for the [HITL](hitl.md) pattern — if `challenge` is true, the workflow can pause and hand control to a human. The detection is built in; the response is up to the workflow.

---

## Migrating from the v0.10 ref format

Before v0.11, refs were assigned by an incrementing counter: `e1`, `e2`, `e3`, … This had two problems: refs were not stable across snapshots (the same element could be `e1` once and `e3` next time), and there was no way to recover from DOM drift.

The v0.11 wire format changes refs to `e<7-hex>` (optionally with a `-N` suffix for collisions inside one snapshot). `PROTOCOL_VERSION` is now `"3"`.

If you have:

- **Hand-written test fixtures** that reference `e1` / `e2` literally — these will break. Replace with a snapshot lookup keyed on tag + accessible name.
- **Old recording logs** captured under v0.10 — replay still works through the selector path, but fingerprint fallback is unavailable until the recording is re-captured.
- **Clients pinned to `protocol_version: "2"`** — bump to `"3"` and verify ref-shape regexes (`/^e\d+$/` → `/^e[0-9a-f]{7}(-\d+)?$/`).

---

## What next?

- [Human-in-the-Loop](hitl.md) — how to pause, hand off to a human, and resume
- [Writing Workflows](../guides/writing-workflows.md) — embed snapshots and ref interactions in a reusable Ruby workflow
- [Command Reference](../reference/commands.md) — full `snapshot` flag documentation

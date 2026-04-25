# Snapshots and Refs

When an AI agent needs to interact with a page, it has to answer two questions: *what is on this page?* and *how do I refer to a specific element?*

CSS selectors are the traditional answer to the second question. They work well when a human writes them by hand in a test suite they own. They break in three ways when an AI agent generates them at runtime:

- **Fragility.** A selector like `div.auth-form > input:nth-child(2)` breaks whenever a developer refactors the markup, adds a wrapper element, or renames a class.
- **Verbosity.** Selectors are long relative to the information they carry. An agent that echoes selectors back to the model burns tokens on structure rather than semantics.
- **No natural language anchor.** The model has to generate a precise CSS path from the page's HTML. That requires reasoning about DOM structure rather than just identifying the element by what it is.

browserctl uses a different model: **refs**.

---

## The snapshot

`browserctl snap <page>` inspects the live page and returns a compact JSON array of every interactable element — inputs, buttons, links, selects, textareas. Static elements that cannot be acted on are omitted.

```bash
browserctl snap login
```

```json
[
  {
    "ref": "e1",
    "tag": "input",
    "text": "",
    "selector": "form > input[name=email]",
    "attrs": {
      "type": "email",
      "name": "email",
      "placeholder": "Enter email"
    }
  },
  {
    "ref": "e2",
    "tag": "input",
    "text": "",
    "selector": "form > input[name=password]",
    "attrs": {
      "type": "password",
      "name": "password"
    }
  },
  {
    "ref": "e3",
    "tag": "button",
    "text": "Sign in",
    "selector": "form > button",
    "attrs": {
      "type": "submit"
    }
  }
]
```

Each element carries:
- **`ref`** — a short, stable ID assigned by the snapshot (e.g. `e1`, `e2`, `e3`)
- **`tag`** — the element type (`input`, `button`, `a`, `select`, etc.)
- **`text`** — visible text or label
- **`selector`** — the CSS selector, included as a fallback
- **`attrs`** — relevant attributes (type, name, placeholder, href, etc.)

The format is intentionally compact. An agent processing a snapshot pays for element count, not DOM depth.

---

## Ref-based interaction

After a snapshot, use the `ref` values directly for subsequent commands. No selector needed:

```bash
browserctl fill  login --ref e1 --value me@example.com
browserctl fill  login --ref e2 --value s3cr3t
browserctl click login --ref e3
```

Refs are valid until the next `snap` call. Every snapshot assigns refs from scratch — `e1` in one snapshot is not guaranteed to refer to the same element as `e1` in the next. They are not positional — `e3` doesn't mean "the third element." It means "the element that was assigned ref e3 in this snapshot."

An agent workflow looks like this:

```
1. snap login           → receive JSON with refs
2. identify e1 as the email field (by tag, name, placeholder)
3. fill login --ref e1  → no selector reasoning required
4. click login --ref e3 → submit
5. snap login           → observe the result
```

The model sees semantics, not structure. The selector is there in the JSON if needed, but in practice the ref + metadata is enough to act correctly.

---

## Diff snapshots

After the first snapshot, subsequent snapshots can return only the elements that changed since the last one:

```bash
browserctl snap login --diff
```

This is useful in two situations:

**Async updates.** After clicking a button that triggers an API call, `snap --diff` tells you exactly which elements appeared or changed — a loading spinner becoming a success message, a table row added, a disabled button becoming enabled. You don't have to diff the full page yourself.

**Token efficiency.** If the page has 80 elements and only 3 changed after an action, there's no reason to re-read all 80. The diff surfaces just the signal.

---

## Refs and recording

When you record a session with `browserctl record start <name>`, each command is captured and later replayed as a workflow. Selector-based interactions (`fill login input[name=email] value`) replay perfectly — the selector is stable.

Ref-based interactions (`fill login --ref e1 --value me@example.com`) cannot replay by ref, because refs are assigned fresh on each snapshot and are not stable across sessions.

browserctl handles this transparently: ref-based interactions are captured as commented-out TODO stubs in the generated workflow:

```ruby
# TODO: ref-based fill on "login" (ref: e1) — replace with a stable CSS selector
# step "TODO: ref-based fill on login (ref: e1)" do
#   page(:login).fill("YOUR_SELECTOR_HERE", params[:fill_value])
# end
```

When `record stop` detects any ref-based interactions in the recording, it prints a warning:

```
Warning: 2 ref-based interaction(s) were captured but cannot be replayed by ref.
Search the generated workflow for 'TODO: ref-based' and replace with stable CSS selectors.
```

The easiest fix: take the `selector` value from the snapshot JSON for that ref and paste it into the generated step.

---

## HTML format

When a model needs to understand page structure rather than interact with specific elements, pass `--format html`:

```bash
browserctl snap login --format html
```

This returns the full page HTML. Useful for reading content, understanding layout, or extracting information. For interaction, use the default JSON format.

---

## Cloudflare challenge signals

Both `snap` and `goto` include a `challenge` field in their response when a Cloudflare interstitial is detected on the page:

```json
{ "challenge": true, ... }
```

This is the entry point for the [HITL](hitl.md) pattern — if `challenge` is true, the workflow can pause and hand control to a human. The detection is built in; the response is up to the workflow.

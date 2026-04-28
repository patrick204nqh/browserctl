# Getting Started

This guide gets you from zero to a working browser session in about five minutes.

## Prerequisites

- Ruby >= 3.3
- Chrome or Chromium on your `PATH`

Check:

```bash
ruby --version    # should be 3.3+
which chromium || which google-chrome || which chrome
```

---

## Install

```bash
gem install browserctl
```

Or add to your `Gemfile`:

```ruby
gem "browserctl"
```

---

## 1. Start the daemon

`browserd` is the background process that keeps the browser alive. Start it once:

```bash
browserd &
```

For a visible browser window (useful when debugging, or when you need to interact manually):

```bash
browserd --headed &
```

Confirm it's running:

```bash
browserctl daemon ping
# → {"ok":true,"pid":12345,"protocol_version":"2"}
```

---

## 2. Open a named page

Open a browser tab and give it a name:

```bash
browserctl page open main --url https://example.com
```

The name (`main`) is what you'll use to address this tab in every subsequent command. Call it anything — `login`, `dashboard`, `session-1`.

---

## 3. Take a snapshot

Snapshot the page to see what's on it:

```bash
browserctl snapshot main
```

You'll get a compact JSON array of every interactable element on the page, each with a short ref ID:

```json
[
  {
    "ref": "e1",
    "tag": "a",
    "text": "More information...",
    "selector": "body > div > p > a",
    "attrs": { "href": "https://www.iana.org/domains/reserved" }
  }
]
```

These ref IDs are how you interact with elements without writing CSS selectors.

---

## 4. Navigate and interact

Navigate to a different URL on the same named page:

```bash
browserctl navigate main https://the-internet.herokuapp.com/login
```

Snapshot again to discover the form fields:

```bash
browserctl snapshot main
```

Fill and submit using refs:

```bash
browserctl fill  main --ref e1 --value tomsmith
browserctl fill  main --ref e2 --value SuperSecretPassword!
browserctl click main --ref e3
```

Check where you ended up:

```bash
browserctl url main
```

---

## 5. Observe results

Take a screenshot:

```bash
browserctl screenshot main --out /tmp/after-login.png --full
```

Snapshot again to see what changed — use `--diff` to get only the elements that are different from the last snapshot:

```bash
browserctl snapshot main --diff
```

---

## 6. Shut down

```bash
browserctl daemon stop
```

The daemon stops and the browser closes. Your session state is gone — next time you'll start fresh.

> The daemon also shuts itself down automatically after 30 minutes of inactivity.

---

## What next?

You just drove a live browser from the command line with no scripts and no selectors. Here's where to go from here:

**Understand the model**
- [Sessions and Pages](concepts/sessions-and-pages.md) — why the daemon exists and how named pages work
- [Snapshots and Refs](concepts/snapshots-and-refs.md) — how the JSON snapshot format works and why refs beat selectors
- [Human-in-the-Loop](concepts/hitl.md) — how to handle the parts of the web that fight back

**Do real things**
- [Writing Workflows](guides/writing-workflows.md) — automate multi-step flows with the Ruby DSL
- [Handling Challenges](guides/handling-challenges.md) — Cloudflare, 2FA, and the pause/resume pattern
- [Smoke Testing](guides/smoke-testing.md) — walkthrough of ready-to-run examples

**Look things up**
- [Command Reference](reference/commands.md) — every command and flag

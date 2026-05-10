# Getting Started

This guide gets you from zero to a working browser session in about five minutes.

## Prerequisites

- Ruby >= 3.3
- Chrome or Chromium on your `PATH`

> On macOS, Chrome installed as a `.app` bundle (the standard installer) is not on your PATH — `browserd` locates it automatically via its default install path, so no PATH configuration is needed.

Check:

```bash
ruby --version    # should be 3.3+
which chromium || which google-chrome || which chrome
```

---

## Install

**macOS (Homebrew — recommended)**

```bash
brew install patrick204nqh/tap/browserctl
```

**RubyGems**

```bash
gem install browserctl
```

Or add to your `Gemfile` (for projects using the client API directly):

```ruby
gem "browserctl"
```

---

## 1. Start the daemon

`browserd` is the background process that keeps the browser alive. Start it once:

```bash
browserd &
```

For a visible browser window — required if you need to solve Cloudflare challenges or 2FA prompts manually, or if you want to watch interactions in real time:

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
browserctl page open main --url https://the-internet.herokuapp.com/login
```

The name (`main`) is what you'll use to address this tab in every subsequent command. Call it anything — `login`, `dashboard`, `session-1`.

---

## 3. Take a snapshot

Snapshot the page to see what's on it:

```bash
browserctl page snapshot main
```

You'll get a compact JSON array of every interactable element on the page, each with a short ref ID:

```json
[
  {
    "ref": "e1",
    "tag": "input",
    "placeholder": "Username",
    "selector": "input[name='username']",
    "attrs": { "type": "text", "name": "username" }
  },
  {
    "ref": "e2",
    "tag": "input",
    "placeholder": "Password",
    "selector": "input[name='password']",
    "attrs": { "type": "password", "name": "password" }
  },
  {
    "ref": "e3",
    "tag": "button",
    "text": "Login",
    "selector": "button[type='submit']",
    "attrs": { "type": "submit" }
  }
]
```

These ref IDs are how you interact with elements without writing CSS selectors.

> **Note:** Ref IDs are valid for the current page state only. Always take a fresh snapshot before interacting — refs change when the page updates.

---

## 4. Fill and submit

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

## 5. Check the result

Take a screenshot:

```bash
browserctl page screenshot main --out /tmp/after-login.png --full
```

Snapshot again to see what changed — use `--diff` to get only the elements that are different from the last snapshot:

```bash
browserctl page snapshot main --diff
```

---

## 6. Save your session (optional)

If you want to pick up exactly where you left off next time — same tabs, same cookies, same auth — save your session before stopping:

```bash
browserctl session save my-first-session
```

Restore it on a fresh daemon:

```bash
browserd &
browserctl session load my-first-session
# → pages re-opened, cookies restored, localStorage seeded
```

---

## 7. Shut down

```bash
browserctl daemon stop
```

The daemon stops and the browser closes. Unsaved session state is gone — next time you'll start fresh unless you saved above.

> The daemon also shuts itself down automatically after 30 minutes of inactivity.

---

## 8. Your first workflow (optional)

CLI commands are great for one-off exploration. Workflows let you save a sequence of steps as a reusable Ruby script:

```ruby
# .browserctl/workflows/hello.rb
Browserctl.workflow "hello" do
  desc "Open a page, print its title"

  step "open page" do
    open_page(:main, url: "https://example.com")
  end

  step "print title" do
    title = page(:main).evaluate("document.title")
    puts "  → #{title}"
  end
end
```

```bash
browserctl workflow run hello
# → Example Domain
```

That's the complete mental model: `open_page` opens a tab, `page(:name)` addresses it, `evaluate` runs JavaScript on it. Everything else in the [Writing Workflows](guides/writing-workflows.md) guide builds on these three primitives.

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

---

## Troubleshooting

### `browserd` is not running

If any command returns an error like `browserd is not running`, or:

```json
{ "ok": false, "daemon": "offline", "error": "browserd is not running — start it with: browserd" }
```

Start the daemon:

```bash
browserd &
```

Confirm it's running:

```bash
browserctl daemon ping
# → {"ok":true,"pid":12345,"protocol_version":"2"}
```

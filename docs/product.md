# browserctl — Product Story

> Navigate the web. Stay in session. Never start over.

---

## The Problem

Every engineer has a browser tab problem.

You spend 30 minutes reproducing a bug — click by click, form by form — that someone else reported with "it broke on checkout." You grab evidence manually: screenshots, copied URLs, pasted error messages into a ticket. You write a Selenium test that passes in CI and breaks on Monday because someone renamed a class. You hire a junior dev to manually verify 12 staging environments every release. You write a scraper that dies on the first Cloudflare interstitial.

These are not automation problems. They are **control problems**. You need to be in charge of the browser — not fighting with it.

---

## The Solution

browserctl is a **persistent browser daemon with a Unix CLI and a Ruby DSL**, purpose-built for engineers and AI agents that need to control the web without babysitting it.

The browser runs as a background process. You — or your agent — command it from the terminal or from code. Sessions survive across commands. When automation hits a wall, you step in, finish the action, and hand it back. Everything is captured.

---

## Four Things That Make It Different

### 1. Human-in-the-loop is the architecture, not the fallback

Every other automation tool treats human intervention as failure. browserctl treats it as a first-class primitive.

When an agent hits a Cloudflare challenge, a 2FA prompt, a payment confirmation screen, or anything that requires a judgment call — the browser stays alive. A human steps in and completes the action. The agent resumes exactly where it stopped, with every cookie, every session token, every piece of in-page state intact.

```bash
browserctl pause main     # hand control to human
# human solves the challenge in the live browser
browserctl resume main    # agent continues mid-task
```

This is not a workaround. It is the intended workflow.

### 2. Reproduce anything. Share it as code.

The `record` command captures a live browser session as a replayable Ruby workflow. Reproduce a bug once, record the steps, hand the script to a colleague.

```bash
# Record the session
browserctl record start my-bug
# ... interact in the browser ...
browserctl record stop

# Later: replay it against any environment
browserctl workflow run my-bug --url https://staging.example.com
```

Evidence is not an afterthought. Screenshots are named, dated, and stored. Every HITL pause is logged with context. The session trace is yours to export.

### 3. You own everything. Zero telemetry.

The daemon runs on your machine. It communicates over a Unix socket. There is no cloud layer, no remote endpoint, no third-party process watching your session.

Your cookies, session tokens, page content, and credentials never leave the machine you're running on. You can run it behind a VPN, offline, inside a private network. No license server. No usage metrics sent home. No SaaS account required.

### 4. Code as browser control

If it happens in a browser, it can happen in code.

```ruby
Browserctl.workflow :verify_checkout do
  desc "End-to-end checkout smoke test with evidence capture"

  param :email, required: true
  param :password, required: true, secret: true

  step "navigate to login" do
    page(:main).navigate("https://shop.example.com/login")
    page(:main).screenshot(path: "evidence/login-page.png")
  end

  step "authenticate" do
    page(:main).fill("input[name=email]", email)
    page(:main).fill("input[name=password]", password)
    page(:main).click("button[type=submit]")
  end

  step "confirm checkout reached" do
    page(:main).wait("[data-test=checkout-header]", timeout: 15)
    page(:main).screenshot(out: "evidence/checkout.png")
  end
end
```

Workflows are plain Ruby. They compose, retry, timeout, and share steps. Params are typed. Secrets are never written to recordings.

---

## Who It's For

**Engineers debugging issues** — Record the reproduction steps. Capture screenshots at each stage. Share the workflow script instead of a 10-step Confluence doc.

**AI/agent teams** — Give your agent a browser it can actually use on the real web — Cloudflare walls, consent modals, 2FA prompts and all. The agent handles the mechanical work; HITL handles the judgment calls.

**QA and release teams** — Smoke test every environment with the same script. Record the passing run as evidence. Replay it before the next release.

**Anyone with browser toil** — If you click through the same 12 pages every week, write the workflow once and delegate it.

---

## What It Is Not

- Not a test framework (use Capybara for assertions-in-CI)
- Not a cloud browser service (the daemon runs on your machine, period)
- Not a scraping library (use Nokogiri for HTML-only work)
- Not a Playwright replacement in CI pipelines
- Not a GUI tool

browserctl occupies a specific space: **interactive, stateful, composable browser control — for the parts of your work that deserve automation but have always required a human because they're too messy to automate cleanly**.

---

## The One-Line Pitch

> The browser you delegate to your agents — with a pause button for the parts that still need you.

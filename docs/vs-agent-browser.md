# browserctl vs. vercel-labs/agent-browser

> agent-browser details are based on the project's public documentation and README as of writing. Check the [upstream repo](https://github.com/vercel-labs/agent-browser) for the latest.

Both projects exist to solve the same root problem: AI agents need stateful, persistent browser sessions. The way each project answers that problem reveals fundamentally different philosophies.

---

## What they share

- Persistent browser sessions that survive across agent turns (no cold-start on every command)
- Unix domain socket transport with a JSON-RPC command protocol
- Chrome DevTools Protocol (CDP) as the browser control layer (no Playwright dependency)
- Semantic ref-based interaction — elements are addressed by a stable ID from the snapshot, not a fragile CSS selector
- Multi-session support for running parallel agent instances
- Session recording (shipped in browserctl v0.2; on agent-browser's roadmap)

---

## Where browserctl diverges

### 1. Local-only, by design

agent-browser runs locally by default but also integrates with cloud browser providers (Browserless, Browserbase, AWS AgentCore). browserctl has no cloud integration path — the daemon runs on your machine, period.

This is a deliberate constraint, not a gap. A strictly local daemon means:
- Zero network latency between your agent and the browser
- No third-party access to your session cookies, credentials, or page content
- Works offline, behind a VPN, or inside a private network
- The daemon is a process you own, kill, and restart like any other

### 2. Human-in-the-loop is a first-class primitive

agent-browser assumes the agent operates autonomously. browserctl treats **human presence as a resumable event**.

When automation hits a wall — a Cloudflare challenge, a 2FA prompt, a CAPTCHA, a consent modal — the agent calls `pause`. The browser stays alive. A human steps in, completes the action, and calls `resume`. Automation continues exactly where it stopped, with the full session state intact.

This is not a workaround. It is the intended workflow.

```
browserctl pause main   # hand control to human
# human completes the challenge in the live browser
browserctl resume main  # agent continues
```

agent-browser has no equivalent pause/resume primitive.

### 3. Blocker detection surfaced explicitly

Knowing *when* to pause is as important as being able to pause. browserctl ships with built-in detection for known blockers:

- **Cloudflare challenges** — `snapshot` and `goto` responses include a `challenge: true` field when a Cloudflare interstitial is detected

The detection layer is designed to grow. The same pattern that detects Cloudflare can be extended to detect:
- Bot-detection pages (DataDome, PerimeterX, Arkose)
- 2FA / MFA prompts
- Consent / cookie banners requiring human judgment
- Payment confirmation screens

Rather than hardcoding responses to each blocker, browserctl surfaces the signal and lets the agent (or the workflow) decide: pause and wait, retry, or abort.

agent-browser does not surface blocker signals in its responses.

### 4. Workflow layer — composable, replayable Ruby DSL

agent-browser is a command-per-call tool. browserctl adds a workflow layer on top: multi-step workflows defined in Ruby, with `compose` for reuse, `retry_count:` and `timeout:` per step, typed `param:` declarations, and secret-safe recording.

The `record` command captures a live session as a replayable workflow file. Reproduce a bug once, hand the script to a colleague.

```ruby
Browserctl.workflow :checkout_smoke do
  param :email, required: true
  param :password, required: true, secret: true

  step "login" do
    page(:main).goto("https://shop.example.com/login")
    snap = page(:main).snapshot
    page(:main).fill(snap.ref(:email_field), email)
    page(:main).fill(snap.ref(:password_field), password)
    page(:main).click(snap.ref(:submit))
  end
end
```

agent-browser has no workflow layer.

---

## Where agent-browser is ahead

### Command breadth

agent-browser ships 100+ commands covering network interception, HAR recording, Web Vitals metrics, PDF export, React component profiling, and a `chat` command for natural-language browser control. browserctl covers ~20 commands. This gap is intentional in the short term — browserctl prioritises depth (HITL, detection, workflows) over breadth — but it is a real difference for teams that need network-level observability or performance metrics today.

### Prompt injection safety

agent-browser wraps `snapshot` output in nonce-delimited content boundaries, preventing a malicious page from embedding fake agent commands in the DOM and having them executed. browserctl snapshots carry no such boundary marker. This matters when running agents against untrusted or adversarial pages.

### Live viewport streaming

agent-browser provides a WebSocket-based dashboard with a live browser viewport, useful for pair-browsing and debugging agent sessions in real time. browserctl has no live preview — inspection is via `browserctl inspect` which opens Chrome DevTools, not a streaming view.

---

## Summary

| | browserctl | agent-browser |
|---|---|---|
| **Runtime** | Ruby / Ferrum / CDP | Rust native binary / CDP |
| **Transport** | Unix socket (JSON-RPC) | Unix socket (JSON-RPC) |
| **Deployment** | Local-only daemon | Local daemon + optional cloud providers |
| **Interaction model** | Ref-based (token-efficient JSON snapshot) | Ref-based (accessibility tree) |
| **HITL** | First-class — `pause`/`resume` primitive | Not implemented |
| **Blocker detection** | Built-in (Cloudflare), extensible | Not surfaced |
| **Workflow layer** | Ruby DSL, compose, record, replay | None |
| **Prompt injection safety** | Not yet | Content boundaries (nonce-wrapped output) |
| **Command surface** | ~20 commands | 100+ commands |
| **Live preview** | DevTools via `inspect` | WebSocket viewport streaming |

browserctl is not trying to be the browser-for-every-framework. It is the browser for agents that work alongside humans, run on your machine, and need to handle the web as it actually is — not as a clean, bot-friendly surface.

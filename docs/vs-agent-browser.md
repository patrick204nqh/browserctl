# browserctl vs. vercel-labs/agent-browser

> agent-browser details are based on the project's public documentation and README as of writing. Check the [upstream repo](https://github.com/vercel-labs/agent-browser) for the latest.

Both projects exist to solve the same root problem: AI agents need stateful, persistent browser sessions. The way each project answers that problem reveals fundamentally different philosophies.

---

## What they share

- Persistent browser sessions that survive across agent turns (no cold-start on every command)
- An agent-friendly API surface that exposes browser actions as structured tool calls
- Multi-session support for running parallel agent instances
- Session recording (shipped in browserctl v0.2; on agent-browser's roadmap)

---

## Where browserctl diverges

### 1. Local-only, by design

agent-browser targets cloud-hosted browser sessions on Vercel infrastructure. browserctl runs as a local Unix daemon — a background process on your machine, reachable over a Unix socket. There is no cloud layer, no remote endpoint, no SaaS dependency. The browser is yours.

This is a deliberate constraint, not a gap. A local daemon means:
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

### 3. Extensible HITL detection

Knowing *when* to pause is as important as being able to pause. browserctl ships with built-in detection for known blockers:

- **Cloudflare challenges** — `snapshot` and `goto` responses include a `challenge: true` field when a Cloudflare interstitial is detected

The detection layer is designed to grow. The same pattern that detects Cloudflare can be extended to detect:
- Bot-detection pages (DataDome, PerimeterX, Arkose)
- 2FA / MFA prompts
- Consent / cookie banners requiring human judgment
- Payment confirmation screens

Rather than hardcoding responses to each blocker, browserctl surfaces the signal and lets the agent (or the workflow) decide: pause and wait, retry, or abort.

### 4. Claude Code-native

agent-browser is framework-agnostic — it works with LangChain, LlamaIndex, the Vercel AI SDK, and others. That breadth comes at the cost of depth.

browserctl ships as an installable Claude Code plugin:

```
/plugin marketplace add patrick204nqh/browserctl
```

Once installed, the `browserctl` skill is available directly in Claude's tool use loop — no configuration, no API keys, no wrapper code. The integration is not an afterthought; it is the primary distribution channel.

### 5. Ref-based interaction (no fragile selectors)

agent-browser uses standard Playwright selectors and screenshots. browserctl uses a different model: `snap` returns a compact token-efficient JSON snapshot where every interactive element has a stable `ref` ID. Subsequent commands use the ref, not a CSS selector:

```
browserctl snap login-page           # → { ref: "e3", tag: "input", ... }
browserctl fill login-page --ref e3 --value "user@example.com"
```

Refs survive DOM mutations that would break a selector. They also carry no positional assumptions, which matters when the page layout changes between agent turns.

---

## Summary

| | browserctl | agent-browser |
|---|---|---|
| **Runtime** | Ruby / Ferrum / CDP | TypeScript / Playwright |
| **Transport** | Unix socket (JSON-RPC) | WebSocket / HTTP |
| **Deployment** | Local-only daemon | Cloud-first (Vercel) |
| **HITL** | First-class — pause/resume primitive | Not a primary feature |
| **Blocker detection** | Built-in (Cloudflare), extensible | Not built-in |
| **Integration** | Claude Code plugin | MCP / framework-agnostic |
| **Interaction model** | Ref-based (token-efficient JSON) | Selectors + screenshots |

browserctl is not trying to be the browser-for-every-framework. It is the browser for agents that work alongside humans, run on your machine, and need to handle the web as it actually is — not as a clean, bot-friendly surface.

# Sessions and Pages

Most browser automation tools think in scripts. You write a script, it spins up a browser, it does its thing, and the browser closes. The next script starts from nothing.

That model works fine for a CI test suite. It breaks immediately when an AI agent needs to browse the web.

An agent doesn't run a single script. It runs a loop — receive instruction, take action, observe result, decide next action. Each iteration is a separate call. If the browser resets between calls, every iteration costs a cold start: fresh cookies, lost authentication, blank localStorage, no context. The agent isn't steering a browser. It's repeatedly driving off a cliff and starting over.

browserctl solves this with a daemon.

---

## The daemon

`browserd` is a background process — not a library, not a script helper, but a long-lived server. It starts once and keeps running. It manages a real Chrome or Chromium instance and holds it open.

```bash
browserd &        # starts in the background, headless
browserd --headed # starts with a visible window
```

The daemon listens on a Unix socket at `~/.browserctl/browserd.sock`. Every `browserctl` command sends a JSON-RPC message over that socket and prints the result. The browser never closes between commands — it waits.

The daemon shuts itself down after 30 minutes of inactivity to avoid orphan processes. `browserctl shutdown` stops it immediately.

---

## Named pages

Inside the daemon, each browser tab is a **named page**. You give it a name when you open it, and you use that name for every subsequent command.

```bash
browserctl open login --url https://app.example.com/login
browserctl fill login "input[name=email]" me@example.com
browserctl snap login
browserctl close login
```

Names are arbitrary strings — `login`, `dashboard`, `checkout`, `agent-session-42`. Naming matters for two reasons:

**1. Multiple tabs.** An agent often needs to hold several pages open at once — a login page, a dashboard, a settings panel. Named handles make it unambiguous which tab you're talking to.

**2. Resumability.** After a pause, after a retry, after any interruption, the name is the stable reference. You don't track a tab ID or an index. You track a name you chose.

```bash
browserctl pages   # lists all open named pages and their current URLs
```

---

## Session state

Everything the browser accumulates — cookies, localStorage, authenticated sessions, form input, open tabs — stays alive as long as the daemon runs. A later command picks up exactly where an earlier one left off.

This is the core property that makes browserctl useful for AI agents. An agent can:
1. Navigate to a login page
2. Fill credentials
3. Complete a CAPTCHA with human help (see [HITL](hitl.md))
4. Navigate to five different pages across the authenticated session
5. Come back an hour later and still be logged in

No re-authentication. No cookie injection. The session is just alive.

---

## Multi-agent isolation

When you need multiple independent browser sessions running in parallel — separate agents, separate users, separate contexts — run multiple named daemon instances:

```bash
browserd --name agent-a &
browserd --name agent-b &

browserctl --daemon agent-a open main --url https://app.example.com
browserctl --daemon agent-b open main --url https://staging.example.com
```

Each daemon manages its own Chrome instance with its own cookie jar. Commands routed to `agent-a` never affect `agent-b`. This is the mechanism for agent fleet use cases where you need N isolated sessions running simultaneously.

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

The daemon shuts itself down after 30 minutes of inactivity to avoid orphan processes. `browserctl daemon stop` stops it immediately.

---

## Named pages

Inside the daemon, each browser tab is a **named page**. You give it a name when you open it, and you use that name for every subsequent command.

```bash
browserctl page open login --url https://app.example.com/login
browserctl fill login "input[name=email]" me@example.com
browserctl snapshot login
browserctl page close login
```

Names are arbitrary strings — `login`, `dashboard`, `checkout`, `agent-session-42`. Naming matters for two reasons:

**1. Multiple tabs.** An agent often needs to hold several pages open at once — a login page, a dashboard, a settings panel. Named handles make it unambiguous which tab you're talking to.

**2. Resumability.** After a pause, after a retry, after any interruption, the name is the stable reference. You don't track a tab ID or an index. You track a name you chose.

```bash
browserctl page list   # lists all open named pages and their current URLs
```

---

## In-memory session state

Everything the browser accumulates — cookies, localStorage, authenticated sessions, form input, open tabs — stays alive as long as the daemon runs. A later command picks up exactly where an earlier one left off.

This is the core property that makes browserctl useful for AI agents. An agent can:
1. Navigate to a login page
2. Fill credentials
3. Complete a CAPTCHA with human help (see [HITL](hitl.md))
4. Navigate to five different pages across the authenticated session
5. Come back an hour later and still be logged in

No re-authentication. No cookie injection. The session is just alive.

---

## Saving and restoring sessions

In-memory state is lost when the daemon stops. `session save` captures everything — open pages, cookies, and localStorage — to disk. `session load` restores it into a running daemon, including re-opening every saved page at its saved URL.

```bash
# After logging in and navigating to the right state:
browserctl session save github_work           # plaintext (0o600 perms)
browserctl session save github_work --encrypt # AES-256-GCM, key in macOS Keychain

# Next time, on a fresh daemon:
browserd &
browserctl session load github_work
# → pages are back, cookies are restored, localStorage is seeded
```

Plaintext sessions live in `~/.browserctl/sessions/<name>/` as `0o600` JSON files. Encrypted sessions store `.enc` blobs instead — the decryption key is kept in macOS Keychain and retrieved transparently on load:

```
~/.browserctl/sessions/github_work/
  metadata.json            # page names + URLs + timestamps (always plaintext)
  cookies.json             # plaintext, or…
  cookies.json.enc         # …AES-256-GCM blob when --encrypt was used
  local_storage.json(.enc)
  session_storage.json(.enc)
```

To share a session or move it to another machine, export it as a zip. Add `--encrypt` to protect the archive with a passphrase (prompted on export; detected automatically on import):

```bash
browserctl session export github_work ~/sessions/github_work.zip
browserctl session export github_work ~/sessions/github_work.zip --encrypt

browserctl session import ~/sessions/github_work.zip  # detects encryption automatically
```

List and manage sessions:

```bash
browserctl session list
browserctl session delete github_work
```

### Session security

Session files contain cookies and localStorage values — which may include authentication tokens, session IDs, and other secrets. Two protections are in place by default:

- `cookies.json` and `local_storage.json` are written with `0o600` permissions (owner read/write only)
- `~/.browserctl/sessions/` is git-ignored when you run `browserctl init`

**Keep session files out of repositories and shared directories.** A stolen session zip gives the holder all the authenticated access captured in that session.

### Keeping credentials out of workflows

Workflow `param` declarations can source secrets directly from your keychain or secret manager at runtime, so credentials never appear in CLI flags, shell history, or workflow files:

```ruby
param :password,  secret_ref: "keychain://MyApp/admin"   # macOS Keychain
param :api_token, secret_ref: "op://Personal/Gmail/token" # 1Password
param :ci_key,    secret_ref: "env://CI_SECRET_TOKEN"      # env var
```

Built-in resolvers cover `env://`, `keychain://` (macOS), and `op://` (1Password CLI). Third-party resolvers can be registered in `~/.browserctl/resolvers.rb`. See [Writing Workflows — Sourcing secrets with `secret_ref:`](../guides/writing-workflows.md#sourcing-secrets-with-secret_ref) for the full reference.

---

## localStorage and sessionStorage

`storage get/set/export/import/delete` give direct access to the page's Web Storage without injecting custom scripts.

```bash
browserctl storage get  main user_id
browserctl storage set  main theme dark
browserctl storage export main /tmp/storage.json
browserctl storage import main /tmp/storage.json
browserctl storage delete main
```

Use `--store session` for sessionStorage (default is `local`):

```bash
browserctl storage get main session_token --store session
```

Inside a workflow, `storage_get` and `storage_set` are available directly on the page proxy:

```ruby
token = page(:main).storage_get("auth_token")
page(:main).storage_set("theme", "dark")
```

---

## Multi-agent isolation

When you need multiple independent browser sessions running in parallel — separate agents, separate users, separate contexts — run multiple named daemon instances:

```bash
browserd --name agent-a &
browserd --name agent-b &

browserctl --daemon agent-a page open main --url https://app.example.com
browserctl --daemon agent-b page open main --url https://staging.example.com
```

Each daemon manages its own Chrome instance with its own cookie jar. Commands routed to `agent-a` never affect `agent-b`.

If you start a second unnamed daemon while the first is running, it auto-picks the next available slot rather than aborting:

```bash
browserd &   # starts as "default"
browserd &   # default slot taken — starts as "d1", prints connection hint
```

Use `browserctl daemon list` to see all running instances.

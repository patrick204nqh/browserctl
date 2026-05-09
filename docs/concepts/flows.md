# Flows

A flow is a named, parameterised, secret-aware procedure for getting a browser into a particular state. Logging into GitHub. Solving a Cloudflare challenge. Walking the Google OAuth consent screen. Things that are tedious to write inline, easy to break, and identical from one project to the next.

Flows are the unit you call when you want auth done. State is the unit you save afterward. Together they let one machine pay the cost of logging in once, hand the result to ten others, and let any of them refresh it on demand.

```
your code  ──▶  flow.run(...)  ──▶  state save ──▶  .bctl bundle
                                                         │
                                                         ▼
                                                   state load on N other machines
                                                         │
                                                         ▼ (when expired)
                                                   state rotate  ──▶  flow.run(...) again
```

---

## Defining a flow

Flows live in plain `.rb` files. browserctl auto-loads them from, in order, `./.browserctl/flows/`, `~/.browserctl/flows/`, then the bundled stdlib (project files win ties).

```ruby
Browserctl.flow("github_login") do
  version "1.0.0"
  desc "Log into github.com with username + password (no 2FA)"

  param :username, required: true
  param :password, required: true, secret_ref: "GitHub/password"

  precondition("page is on github.com") { page.url.include?("github.com") }

  step "fill credentials" do
    page.fill("input[name=login]", username)
    page.fill("input[name=password]", password)
  end

  step "submit" do
    page.click("input[type=submit]")
  end

  postcondition("logged in") { page.snapshot.elements.any? { |e| e[:role] == "navigation" } }

  produces_state do
    { origins: ["https://github.com"] }
  end
end
```

What the DSL gives you:

- **`version`** — required semver, used by `state rotate` to detect breaking flow changes.
- **`desc`** — human description, surfaced by `flow describe` and `flow list`.
- **`param`** — declared inputs. `secret_ref:` resolves through the secret resolver registry (env, macOS Keychain, 1Password). `default:` is for non-secrets only.
- **`precondition` / `postcondition`** — predicates evaluated before/after the steps. Returning false (or raising) stops the flow with a typed error.
- **`step`** — the actual work. Steps run in order; `retry_count:` and `timeout:` are per-step.
- **`produces_state`** — block that returns metadata (origins, hints) the bundle should carry. Optional but recommended.

---

## Running a flow

From the CLI, against an open page:

```bash
browserctl page open work --url https://github.com/login
browserctl flow run github_login --page work --username pat
```

From inside a workflow:

```ruby
Browserctl.workflow("daily_smoke") do
  page :work
  step("login") { invoke :github_login, username: "pat" }
end
```

Programmatically:

```ruby
flow = Browserctl::FlowRegistry.resolve("github_login")
flow.run(page: page_proxy, client: client, username: "pat")
```

Secrets are pulled at run-time, not at parse-time, so a flow file can be loaded on a machine that doesn't have access to its secrets.

---

## Flows and state

A flow run is ephemeral. To persist its result, save state with the flow bound:

```bash
browserctl state save github --flow github_login
```

Then `state rotate github` re-runs the bound flow and overwrites the bundle. WS-5 of v0.10 wires `load_state :github` in workflows to call `state rotate` automatically when the daemon detects an expired bundle, so most code never needs to think about rotation explicitly.

When the auto-rotate path invokes the bound flow, the flow receives the workflow's first open page as its `page` proxy — same convention the daemon's preflight uses for the auth check. That means stdlib flows that read `page.url` or call `page.fill` work the same whether you `flow run` them by hand or let `load_state` invoke them. To override the target page (e.g. a flow that should run against a dedicated `:auth` tab), pass `on_auth_required: -> { invoke :my_flow, page: :auth }` to `load_state`.

---

## Stdlib flows

Bundled inside the gem (will split to `browserctl-flows-stdlib` once the count exceeds ~10 or one needs a heavy optional dependency):

| Flow | What it does |
|---|---|
| `totp_2fa` | Generates a TOTP from a secret and submits it |
| `basic_auth` | Handles HTTP basic-auth prompts |
| `magic_link_email` | Pauses for a click-through link, navigates when it arrives |
| `oauth_google` | Drives the Google OAuth consent screen |
| `oauth_github` | Drives the GitHub OAuth consent screen |
| `cloudflare_solve` | Pauses + HITL signal; captures the resulting cookie |

`browserctl flow list` shows what's available. `browserctl flow describe <name>` shows params, preconditions, and steps.

---

## Versioning

Each flow declares a semver. The manifest in a `.bctl` bundle records the version that produced it. When `state rotate` runs the new version of the flow:

- **Patch / minor bump** — proceed; the bundle is overwritten with the new `flow_version`.
- **Major bump** — refuse to rotate without `--force`. Bundles produced by old major versions are typically incompatible (renamed cookies, new origins).
- **No `flow_version` in the manifest** — pre-v0.10 import; warn once, accept.

---

## See also

- [State](state.md) — what flows produce, what `state rotate` re-runs
- [Writing Workflows](../guides/writing-workflows.md) — the longer-running orchestration layer that calls flows
- [Stdlib Flows](../guides/stdlib-flows.md) — concrete invocation examples for each shipped flow

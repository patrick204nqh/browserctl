# AI-Driven Workflow Authoring

> The replayable loop: explore → generate → check → promote.

This guide walks an AI agent (or a human moving fast) from a one-off browser exploration to a durable, version-controlled workflow that can be invoked from anywhere as a flow.

The pipeline is four CLI commands:

```bash
browserctl record start <name>          # explore interactively
browserctl record stop                  # save the recording
browserctl workflow generate <name>     # → .browserctl/workflows/<name>.rb
browserctl workflow run <name> --check  # × N (default 3 clean runs)
browserctl workflow promote <name> [--as-flow]
```

No manual editing is required for the happy path.

---

## 1. Explore — `record start` / `record stop`

Start a recording session, then drive the browser as you normally would. Every `click`, `fill`, `navigate`, etc. is logged to `~/.browserctl/recordings/<name>.jsonl` along with the snapshot ref, the resolved CSS selector, the element's fingerprint, and a postcondition hint (URL, snapshot digest).

```bash
browserd &
browserctl page open main --url "https://example.com/login"
browserctl record start gh_issues
browserctl fill main "input[name=username]" alice
browserctl fill main "input[name=password]" hunter2
browserctl click main "button[type=submit]"
browserctl navigate main "https://example.com/issues"
browserctl record stop
```

The recording captures *what was tried*, not just what worked. Failed clicks and selector retries also appear in the log so the generator can ignore them.

---

## 2. Generate — `workflow generate`

```bash
browserctl workflow generate gh_issues
# → .browserctl/workflows/gh_issues.rb
```

The generated file is a complete `Browserctl.workflow` definition with:

- Stable CSS selectors first; fingerprint metadata in inline comments as fallback hints.
- Inferred `wait` calls between steps when the recording showed observable delays (>500ms by default).
- `assert url_matches:` / `assert selector_present:` postconditions where the recording observed deterministic post-step state.
- Auto-detected secret-shaped values (passwords, API keys, tokens) replaced with `params[:secret_<field>]` and a `param :secret_<field>, secret: true` declaration. A `# TODO: Configure a secret_ref:` header lists candidates for each.

Open the generated file. The only edit you typically need is wiring secret resolvers — change `secret: true` to `secret_ref: "op://Vault/Item/key"` (or `env://`, `keychain://`, etc.).

---

## 3. Check — `workflow run --check`

`--check` replays the workflow and compares each post-step snapshot against the recorded one.

```bash
browserctl workflow run gh_issues --check
```

Three outcomes, signalled by exit code:

| Exit | Verdict | What it means |
|------|---------|---------------|
| `0`  | `:clean` | Every step passed; no drift; snapshots match. |
| `2`  | `:drift` | Every step passed, but at least one selector was rematched via fingerprint *or* a snapshot diff was non-empty. The workflow is still working but the page has shifted. |
| `1`  | `:fail`  | A step raised. The workflow is broken. |

The drift report (a JSON object printed before exit) lists the events:

```json
{
  "drift": true,
  "rematches": 1,
  "unresolved": 0,
  "events": [{"command": "click", "selector": "form .old", "matched_ref": "ea11111", "score": 0.92, "reason": "rematch"}]
}
```

Each `--check` run is appended to `~/.browserctl/check_ledger.jsonl` and gates promotion.

### Reacting to drift, not failure

A fingerprint rematch is *data*, not a failure. The drift report tells you:

- **Rematches with high score (>0.85)** — the page changed superficially (renamed CSS class, reorganised neighbours). The workflow still works; you can promote on the next clean run, or update the recorded selector if the rematch is annoying.
- **Unresolved drift events** — fingerprint matching couldn't find a candidate above threshold. The workflow may be one page-mutation away from breaking. Re-record before promoting.
- **`:fail`** — a step actually raised. Read the error, fix the selector or the step logic, and re-check.

Don't promote a workflow that drifted. Re-run `--check` until you have N consecutive clean runs.

---

## 4. Promote — `workflow promote`

```bash
browserctl workflow promote gh_issues
# → ~/.browserctl/workflows/gh_issues.rb
```

Promotion copies the workflow from the project-local directory to the user-global one, where it's invocable from any project. The gate is intentionally strict: a promotable workflow must have **3 consecutive `:clean` `--check` runs** in the ledger. `:drift` and `:fail` reset the streak.

Overrides:

| Flag | Effect |
|------|--------|
| `--threshold N` | Lower or raise the streak requirement (default 3). |
| `--force` | Bypass the gate entirely. Use only when you know what you're doing. |
| `--as-flow` | Also write a flow wrapper to `~/.browserctl/flows/<name>.rb`. |

### `--as-flow` — closing the v0.10 loop

```bash
browserctl workflow promote gh_issues --as-flow
```

Generates a thin flow file alongside the promoted workflow. The flow is registered globally and runs the underlying workflow via the runner — params are inferred from the workflow's `param_defs`, so callers see the same surface area:

```ruby
# ~/.browserctl/flows/gh_issues.rb (auto-generated)
Browserctl.flow("gh_issues") do
  version "1.0.0"
  requires_browserctl "0.11.0"
  desc "Promoted from workflow 'gh_issues'"

  param :secret_password, secret: true

  step("run workflow gh_issues") do
    Browserctl::Runner.new.run_workflow("gh_issues", **params)
  end
end
```

Once promoted as a flow, it shows up in `browserctl flow list` and is invocable as `browserctl flow run gh_issues`. The workflow remains the source of truth — edit the workflow file and the flow wrapper picks up the change without regeneration.

---

## End-to-end: one minute, no manual editing

```bash
# 1. Explore
browserd &
browserctl record start scrape_issues
# … drive the browser …
browserctl record stop

# 2. Generate
browserctl workflow generate scrape_issues

# 3. Check (loop until clean)
for i in 1 2 3; do
  browserctl workflow run scrape_issues --check || break
done

# 4. Promote
browserctl workflow promote scrape_issues --as-flow

# 5. Use it from anywhere
browserctl flow run scrape_issues
```

For HITL pauses (auth, captchas) the agent should approve and resume; the recording captures what came before and after the pause and the generator emits the same structure.

---

## See also

- [Snapshots and Refs](../concepts/snapshots-and-refs.md) — how stable refs and fingerprints work under the hood.
- [Writing Workflows](writing-workflows.md) — the workflow DSL reference.
- [Agent Integration](agent-integration.md) — using browserctl from Python, shell, and tool-use agents.
- [Handling Challenges](handling-challenges.md) — Cloudflare, 2FA, pause/resume.

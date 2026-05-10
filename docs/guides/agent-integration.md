# Using browserctl from AI Agents

browserctl exposes a stable CLI and JSON-RPC wire protocol, so any language or agent framework can drive it. This guide shows the most common patterns.

---

## The basic model

Start the daemon once, then issue commands from your agent's tool calls:

```bash
browserd &                         # start once; keeps the browser alive
browserctl page snapshot main      # → JSON array your agent reads
browserctl click main --ref e3     # act on ref IDs from the snapshot
browserctl daemon stop             # clean up when done
```

The daemon stays alive between calls. Sessions persist across your agent's entire run.

---

## Python — subprocess

The simplest integration: shell out to `browserctl` and parse the JSON output.

```python
import subprocess
import json

def ctl(*args):
    result = subprocess.run(
        ["browserctl", *args],
        capture_output=True, text=True, check=True
    )
    return json.loads(result.stdout)

# Open a page
ctl("page", "open", "main", "--url", "https://example.com/login")

# Snapshot — get interactable elements with ref IDs
elements = ctl("snapshot", "main")
# → [{"ref": "e1", "tag": "input", ...}, {"ref": "e2", ...}]

# Interact by ref
username_ref = next(e["ref"] for e in elements if "username" in str(e.get("attrs", {})))
ctl("fill", "main", "--ref", username_ref, "--value", "myuser")
```

---

## Python — Anthropic tool use

Expose browserctl commands as Claude tools:

```python
import anthropic
import subprocess
import json

client = anthropic.Anthropic()

tools = [
    {
        "name": "browser_snapshot",
        "description": "Take a snapshot of the current page and return interactable elements with ref IDs",
        "input_schema": {
            "type": "object",
            "properties": {"page": {"type": "string", "description": "Page name, e.g. 'main'"}},
            "required": ["page"]
        }
    },
    {
        "name": "browser_click",
        "description": "Click an element by its ref ID from a snapshot",
        "input_schema": {
            "type": "object",
            "properties": {
                "page": {"type": "string"},
                "ref": {"type": "string", "description": "Ref ID from snapshot, e.g. 'e3'"}
            },
            "required": ["page", "ref"]
        }
    },
    {
        "name": "browser_fill",
        "description": "Fill a text input by its ref ID",
        "input_schema": {
            "type": "object",
            "properties": {
                "page": {"type": "string"},
                "ref": {"type": "string"},
                "value": {"type": "string"}
            },
            "required": ["page", "ref", "value"]
        }
    }
]

def handle_tool(name, inputs):
    if name == "browser_snapshot":
        out = subprocess.check_output(["browserctl", "snapshot", inputs["page"]])
        return json.loads(out)
    elif name == "browser_click":
        out = subprocess.check_output(["browserctl", "click", inputs["page"], "--ref", inputs["ref"]])
        return json.loads(out)
    elif name == "browser_fill":
        out = subprocess.check_output([
            "browserctl", "fill", inputs["page"], "--ref", inputs["ref"], "--value", inputs["value"]
        ])
        return json.loads(out)
```

---

## Shell / bash agents

For shell-based agent loops, pipe snapshot output through `jq`:

```bash
# Get the ref for the login button
LOGIN_REF=$(browserctl page snapshot main | jq -r '.[] | select(.text == "Login") | .ref')

browserctl click main --ref "$LOGIN_REF"

# Poll until a target element appears
until browserctl page snapshot main | jq -e '.[] | select(.attrs["data-test"] == "dashboard")' > /dev/null; do
  sleep 1
done
```

---

## Session persistence across agent runs

Save state at the end of a run so the next run picks up authenticated:

```bash
# End of run 1
browserctl session save my-agent-session
browserctl daemon stop

# Start of run 2 — no re-login needed
browserd &
browserctl session load my-agent-session
# → cookies restored, localStorage seeded, pages reopened
```

---

## Human-in-the-loop from agent code

When your agent hits a wall (Cloudflare, 2FA, consent banner):

```python
snap = ctl("snapshot", "main")
if snap.get("challenge"):
    print("⚠  Challenge detected — solve it in the browser window, then press Enter")
    subprocess.run(["browserctl", "pause", "main"])
    input()  # wait for human
    subprocess.run(["browserctl", "resume", "main"])
    snap = ctl("snapshot", "main")  # re-snapshot after resume
```

---

## Multi-agent isolation

Run multiple named daemon instances for parallel agents:

```bash
browserd --name agent-a &
browserd --name agent-b &

browserctl --daemon agent-a page open main --url https://app.example.com/user/1
browserctl --daemon agent-b page open main --url https://app.example.com/user/2
```

Each daemon has its own socket, its own browser, and its own session state.

---

## What next?

- [Sessions and Pages](../concepts/sessions-and-pages.md) — how named pages and session persistence work
- [Human-in-the-Loop](../concepts/hitl.md) — the full HITL pattern
- [Command Reference](../reference/commands.md) — every command and flag
- [Examples](../../examples/) — runnable scripts including `session_reuse.rb` and `cloudflare_hitl.rb`

# Human-in-the-Loop (HITL)

The real web is not a clean API. It was not designed for bots, and many parts of it actively resist them.

An AI agent automating a browser will eventually hit something it cannot pass on its own: a Cloudflare challenge that requires solving a CAPTCHA, a 2FA SMS code, a consent modal with a deliberately confusing "Reject All" path, a payment confirmation that legally requires human intent, or a login wall that simply decides this particular headless session looks suspicious today.

Most automation tools fail here. The script crashes. The session is lost. You restart from the beginning.

browserctl treats this differently. **Human presence is a resumable event.**

---

## The pause/resume model

When automation hits a wall, the agent calls `pause`. The browser stays alive — open, authenticated, on the exact page where automation stopped. Control transfers to a human. When the human is done, they call `resume`. Automation continues from exactly where it paused, with the full session state intact.

```bash
browserctl pause main    # hand control to human
# human opens the visible browser window, solves the challenge
browserctl resume main   # agent continues
```

Nothing is lost. Cookies, localStorage, the current URL, the auth session — all preserved. The agent doesn't re-authenticate. It doesn't re-navigate. It picks up mid-task.

This is not a workaround for a limitation. It is the intended workflow for tasks that involve both agent and human actors. The agent handles the mechanical work; the human handles the judgment calls.

---

## Detection: knowing when to pause

Knowing *when* to pause is as important as being able to pause. browserctl builds detection directly into the browsing primitives.

Both `navigate` and `snapshot` include a `challenge` field in their response:

```ruby
res = client.navigate("main", url)
res[:challenge]   # => true when Cloudflare interstitial is detected
```

```bash
browserctl snapshot main   # JSON includes "challenge": true when blocked
```

When `challenge` is true, the workflow decides what to do: pause and wait, retry the navigation, or abort.

**Current built-in signals** (detected in the page body):

| Signal | Meaning |
|--------|---------|
| `cf-challenge-running` | Cloudflare challenge widget is active |
| `cf_chl_opt` | Cloudflare challenge options object present |
| `__cf_chl_f_tk` | Challenge token field present |
| `Just a moment...` | Cloudflare interstitial page title |
| URL contains `challenge-platform` | Challenge platform redirect |

---

## The extensible detection model

Cloudflare is just the first detector. The detection layer is designed to grow — the same mechanism that surfaces Cloudflare signals can surface signals for:

- Other bot-detection systems (DataDome, PerimeterX, Arkose)
- 2FA / MFA prompts
- Consent and cookie banners requiring human judgment
- Payment confirmation screens
- Age verification gates

The philosophy is: **surface the signal, let the workflow decide.** browserctl doesn't try to auto-solve challenges (fragile, constantly broken by vendor updates, often illegal). It identifies that the situation requires attention and hands it off cleanly.

A `register_detector` plugin API is planned for a future release — third-party detectors will be registerable without modifying the core. For now, additional detection logic can be added via the plugin system using `register_command`.

---

## Capturing and reusing clearance

After a human solves a Cloudflare challenge, the browser holds a `cf_clearance` cookie that grants access for subsequent requests. You can capture it and inject it into future sessions to skip re-solving:

```bash
# after solving the challenge:
browserctl cookie list main | jq '.cookies[] | select(.name == "cf_clearance")'

# in a new session:
browserctl page open main
browserctl cookie set main cf_clearance "xyz..." --domain .example.com
browserctl navigate main https://example.com   # passes without a challenge
```

`cf_clearance` cookies expire (typically 30 minutes to a few hours). When they age out, Cloudflare will serve a new challenge.

---

## A full HITL workflow

The pattern in code — detect, pause, poll for resolution, continue:

```ruby
step "navigate to protected page" do
  res = client.navigate("main", target_url)

  if res[:challenge]
    puts "⚠  Challenge detected — solve it in the browser, then: browserctl resume main"
    client.pause("main")

    # wait until the challenge clears
    loop do
      snap = client.snapshot("main", format: "html")
      break unless snap[:challenge]
      sleep 3
    end
  end
end

step "continue as normal" do
  page(:main).wait("[data-test=main-content]", timeout: 15)
  # ...
end
```

See [Handling Challenges](../guides/handling-challenges.md) for a runnable example against a live Cloudflare demo page.

---

## `ask` — Value injection

`ask` is the complement to `pause/resume`. Instead of handing the browser to the human, it asks the human for a single value and resumes immediately.

```ruby
# In a workflow:
code = ask("Enter the 2FA code sent to your phone:")
page("main").fill("#otp-input", code)
page("main").click("#submit")
```

From the CLI:
```sh
code=$(browserctl ask "Enter the 2FA code:")
```

`ask` reads from stdin and writes the value to stdout as JSON. The prompt is written to stderr.

---

## HITL vs. fully autonomous agents

HITL is not a concession to automation limitations. It is an architectural choice about where human judgment belongs in a workflow.

Some tasks are appropriate to fully automate. Others — anything touching payment, legal consent, or security credentials — arguably *should* require a human in the loop by design. browserctl gives you the primitive to make that choice explicitly, rather than having it made for you by a crash or a silent failure.

The long-term vision: pause/resume sessions become **annotated training data**. Every HITL intervention is a labeled example of "agent got stuck here, human did this." That data is directly useful for fine-tuning browser agents that need fewer interventions over time.

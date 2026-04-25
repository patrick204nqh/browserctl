# Handling the Web as It Is

The web wasn't built for bots. Cloudflare challenges, 2FA prompts, consent walls — these are features of the real web, not edge cases. This guide shows how browserctl handles them with the pause/resume HITL pattern.

For the concepts behind HITL, see [Human-in-the-Loop](../concepts/hitl.md).

---

## The demo setup

[nopecha.com/demo/cloudflare](https://nopecha.com/demo/cloudflare) is a public page that reliably serves a Cloudflare Turnstile challenge. Most Cloudflare-protected sites pass a real headed Chrome silently — this demo is specifically configured to always serve the widget, making it ideal for testing the challenge path without needing a real protected site.

```bash
# Start with a visible window — headless fails Cloudflare
browserd --headed &

# Run the example
browserctl run examples/cloudflare_hitl.rb --url https://nopecha.com/demo/cloudflare

browserctl shutdown
```

When the challenge fires, the terminal pauses:

```
  [ok]   open page
  [ok]   navigate to target URL
         ⚠  Cloudflare challenge detected on https://nopecha.com/demo/cloudflare
         → Pausing automation. Solve the challenge in the browser, then run:
              browserctl resume main
```

Solve the Turnstile widget in the open browser window, then:

```bash
browserctl resume main
```

The workflow unblocks and continues:

```
         ✓ Challenge cleared — resuming automation
  [ok]   wait for content and snapshot
  [ok]   close page
```

---

## How challenge detection works

`goto` and `snapshot` inspect the page body for known Cloudflare signals and include a `challenge:` boolean in their response:

| Signal | Meaning |
|--------|---------|
| `cf-challenge-running` | Challenge widget is active |
| `cf_chl_opt` | Cloudflare challenge options object |
| `__cf_chl_f_tk` | Challenge token field |
| `Just a moment...` | Cloudflare interstitial page title |
| URL contains `challenge-platform` | Challenge platform redirect |

```ruby
res = client.goto("main", url)
res[:challenge]   # => true when any signal is present
```

---

## The HITL pattern in code

```ruby
step "navigate to target URL" do
  res = client.goto("main", url)

  if res[:challenge]
    client.pause("main")

    # poll until the human solves the challenge
    loop do
      snap = client.snapshot("main", format: "html")
      break unless snap[:challenge]
      sleep 3
    end
  end
end
```

`pause` blocks all further commands on the named page via a `ConditionVariable`. When `browserctl resume main` is called from any terminal, the CV is signalled and the polling loop proceeds to the `break` check.

---

## Capturing and reusing clearance

After solving a challenge, the browser holds a `cf_clearance` cookie. Capture it to skip re-solving in future sessions:

```bash
browserctl cookies main | jq '.cookies[] | select(.name == "cf_clearance")'
# → { "name": "cf_clearance", "value": "xyz...", "domain": ".example.com", "path": "/" }
```

Restore it in a new session:

```bash
browserctl open main
browserctl set-cookie main cf_clearance "xyz..." ".example.com"
browserctl goto main https://example.com   # no challenge
```

Or from Ruby:

```ruby
client.set_cookie("main", "cf_clearance", "xyz...", ".example.com")
```

> `cf_clearance` cookies expire (typically 30 minutes to a few hours). When they age out, Cloudflare will serve a new challenge.

---

## Adapting to your own URL

```bash
browserctl run examples/cloudflare_hitl.rb --url https://your-protected-site.com
```

Because headed Chrome is a real browser, many Cloudflare zones pass silently without showing a widget. The `if res[:challenge]` branch is a no-op in that case and automation continues normally.

---

## Extending detection to other blockers

The detection model is not limited to Cloudflare. Custom detectors can be registered via the plugin system to surface other blockers — DataDome, 2FA prompts, consent banners — using the same `challenge: true` signal. See [HITL concepts](../concepts/hitl.md#the-extensible-detection-model) for the registration API.

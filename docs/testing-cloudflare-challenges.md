# Testing Cloudflare Challenge Handling

[nopecha.com/demo/cloudflare](https://nopecha.com/demo/cloudflare) is a public demo page that reliably serves a Cloudflare Turnstile challenge, making it ideal for testing browserctl's challenge detection and HITL pause/resume pattern without needing a real protected site.

## Why this demo page

Most Cloudflare-protected sites pass a real headed Chrome silently — you never see a challenge. The NopeCHA demo is specifically configured to always serve a Turnstile widget, so you can reproduce and test the challenge path consistently.

## Running the example

```bash
# Start the daemon with a visible browser window (required — headless fails Cloudflare)
browserd --headed &

# Run the HITL example against the NopeCHA demo
browserctl run examples/cloudflare_hitl.rb --url https://nopecha.com/demo/cloudflare

browserctl shutdown
```

When the challenge is detected, the terminal pauses and prints:

```
  ⚠  Cloudflare challenge detected on https://nopecha.com/demo/cloudflare
  → Pausing automation. Solve the challenge in the browser, then run:
       browserctl resume main
```

Solve the Turnstile widget in the open browser window, then in a second terminal:

```bash
browserctl resume main
```

The workflow unblocks, confirms the challenge is cleared, and captures a snapshot of the post-challenge page:

```
  [ok]   open page
  [ok]   navigate to target URL
         ⚠  Cloudflare challenge detected on https://nopecha.com/demo/cloudflare
         → Pausing automation. Solve the challenge in the browser, then run:
              browserctl resume main
         ✓ Challenge cleared — resuming automation
  [ok]   wait for content and snapshot
  [ok]   close page
```

---

## How challenge detection works

When `goto` or `snapshot` is called, the daemon inspects the page body for known Cloudflare signals:

| Signal | Meaning |
|--------|---------|
| `cf-challenge-running` | Challenge widget is active |
| `cf_chl_opt` | Cloudflare challenge options object |
| `__cf_chl_f_tk` | Challenge token field |
| `Just a moment...` | Cloudflare interstitial page title |
| URL contains `challenge-platform` | Challenge platform redirect |

Both `goto` and `snapshot` responses include a `challenge:` boolean field:

```ruby
res = client.goto("main", url)
res[:challenge]  # => true when any signal is present
```

---

## The HITL pattern

The `cloudflare_hitl.rb` example demonstrates the full pause/resume flow:

```ruby
step "navigate to target URL" do
  res = client.goto("main", url)

  if res[:challenge]
    # Print instructions and pause the page
    client.pause("main")

    # Poll until the human solves the challenge and the signals are gone
    loop do
      snap = client.snapshot("main", format: "html")
      break unless snap[:challenge]
      sleep 3
    end
  end
end
```

The `pause` command blocks all further commands on the named page via a `ConditionVariable`. When `browserctl resume main` is called from any terminal, the CV is signalled and the loop proceeds to the `break` check on the next poll.

---

## Adapting to your own protected URL

Replace the `--url` parameter with any Cloudflare-protected site:

```bash
browserctl run examples/cloudflare_hitl.rb --url https://your-protected-site.com
```

Because headed Chrome is a real browser, many Cloudflare zones pass silently without showing the widget. The `if res[:challenge]` branch is a no-op in that case, and automation continues normally.

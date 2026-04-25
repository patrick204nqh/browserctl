# frozen_string_literal: true

# Demonstrates the Cloudflare HITL (Human-in-the-Loop) pattern.
#
# When an agent navigates to a Cloudflare-protected page and hits a bot challenge,
# it cannot interact with the real page content. This workflow detects the challenge,
# pauses automation so a human can solve it in the live browser, then resumes.
#
# Run:
#   browserctl run examples/cloudflare_hitl.rb --url https://example.com
#
# Note: modern Cloudflare often passes a real headed Chrome without challenge.
# The pause/resume branch fires only when the challenge page is actually served
# (typically against headless or CDP-fingerprinted browsers, or stricter zones).
# When paused, the terminal prints instructions. Solve the challenge in the open
# browser window, then run: browserctl resume main

Browserctl.workflow "cloudflare_hitl" do
  desc "Navigate a Cloudflare-protected URL with human-assisted challenge bypass"

  param :url,      required: true
  param :selector, default: "body"

  step "open page" do
    client.open_page("main")
  end

  step "navigate to target URL" do
    res = client.goto("main", url)

    if res[:challenge]
      $stdout.puts ""
      $stdout.puts "  ⚠  Cloudflare challenge detected on #{url}"
      $stdout.puts "  → Pausing automation. Solve the challenge in the browser, then run:"
      $stdout.puts "       browserctl resume main"
      $stdout.puts ""

      client.pause("main")

      # Block here until the human calls `browserctl resume main`.
      # The pause command marks the page; resume unblocks and signals the CV.
      # In a workflow context, we poll the server until the page is unpaused
      # by attempting a lightweight snapshot — once it succeeds, we're through.
      loop do
        snap = client.snapshot("main", format: "html")
        break unless snap[:challenge]

        $stdout.puts "  … still on challenge page, waiting 3s"
        sleep 3
      end

      $stdout.puts "  ✓ Challenge cleared — resuming automation"
    end
  end

  step "wait for content and snapshot" do
    page(:main).wait_for(selector, timeout: 15)
    result = page(:main).snapshot(format: "elements")
    $stdout.puts "  Snapshot: #{result[:snapshot]&.length || 0} elements captured"
  end

  step "close page" do
    client.close_page("main")
  end
end

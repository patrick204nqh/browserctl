# frozen_string_literal: true

require_relative "../../detectors"
require_relative "../../flow"

# Pauses for a human to solve a Cloudflare challenge (Turnstile, "Just a
# moment...", interactive checkbox), then verifies the challenge cleared
# before returning. Optionally saves the post-solve session under a name
# you can reload later with `state load` or `session_load`.
#
# Reuses Browserctl::Detectors.cloudflare? — the server-side detector
# already shipped in v0.8 — by adapting the client-facing PageProxy to
# the duck-typed (current_url, body) interface the detector expects.
module Browserctl
  module Flows
    PageDetectorAdapter = Struct.new(:current_url, :body)

    module CloudflareSolve
      module_function

      def detect?(page_proxy)
        body = page_proxy.evaluate("document.body && document.body.innerText || ''").to_s
        adapter = PageDetectorAdapter.new(page_proxy.url, body)
        Browserctl::Detectors.cloudflare?(adapter)
      end
    end
  end
end

Browserctl.flow("cloudflare_solve") do
  version "1.0.0"
  requires_browserctl "0.11.0"
  desc "Pause for a human to solve a Cloudflare challenge; verify it cleared; optionally capture state."

  param :prompt,
        default: "Cloudflare challenge detected. Solve it in the browser, then press Enter to continue."
  param :state_name # optional — if set, session_save is called after the challenge clears

  precondition("page proxy is present") { !page.nil? }
  precondition("cloudflare challenge is present") do
    Browserctl::Flows::CloudflareSolve.detect?(page)
  end

  step("wait for human signal") do
    warn "[browserctl] #{prompt}"
    line = $stdin.gets
    raise "stdin closed before user signaled" if line.nil?
  end

  step("verify challenge cleared") do
    raise "cloudflare challenge still detected after human signal" if Browserctl::Flows::CloudflareSolve.detect?(page)
  end

  produces_state do
    next nil unless state_name && client

    client.session_save(state_name)
  end
end

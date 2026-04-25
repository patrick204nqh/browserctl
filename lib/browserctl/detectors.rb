# frozen_string_literal: true

module Browserctl
  module Detectors
    CLOUDFLARE_SIGNALS = [
      "cf-challenge-running",
      "cf_chl_opt",
      "__cf_chl_f_tk",
      "Just a moment..."
    ].freeze

    # Returns true if the page appears to be showing a Cloudflare challenge.
    # Checks both the current URL and the page body for known Cloudflare signals.
    # @param page [Ferrum::Page] the browser page to inspect
    # @return [Boolean]
    def self.cloudflare?(page)
      url  = page.current_url.to_s
      body = page.body.to_s
      url.include?("challenge-platform") ||
        CLOUDFLARE_SIGNALS.any? { |sig| body.include?(sig) }
    end
  end
end

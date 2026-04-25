# frozen_string_literal: true

module Browserctl
  module Detectors
    CLOUDFLARE_SIGNALS = [
      "cf-challenge-running",
      "cf_chl_opt",
      "__cf_chl_f_tk",
      "Just a moment..."
    ].freeze

    def self.cloudflare?(page)
      url  = page.current_url.to_s
      body = page.body.to_s
      url.include?("challenge-platform") ||
        CLOUDFLARE_SIGNALS.any? { |sig| body.include?(sig) }
    end
  end
end

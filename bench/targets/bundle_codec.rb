# frozen_string_literal: true

require "securerandom"
require "browserctl"
require "browserctl/state/bundle"
require_relative "../support/target"

module Browserctl
  module Bench
    # Round-trip benchmark for the unencrypted .bctl codec: encode a realistic
    # state payload (40 cookies + 20 localStorage entries + a manifest) and
    # then decode it back. Encryption (AES-GCM + PBKDF2) is intentionally
    # excluded — PBKDF2 dominates by orders of magnitude and would mask
    # codec-shape regressions.
    module BundleCodecFixtures
      module_function

      def build
        { manifest: manifest, payload: { "cookies" => cookies, "local_storage" => local_storage } }
      end

      def manifest
        { tool: "browserctl", created_at: "2026-05-10T00:00:00Z", profile: "default", host: "example.com" }
      end

      def cookies
        Array.new(40) do |i|
          {
            "name" => "cookie_#{i}", "value" => SecureRandom.hex(32),
            "domain" => "example.com", "path" => "/",
            "expires" => 1_900_000_000 + i, "httpOnly" => true, "secure" => true
          }
        end
      end

      def local_storage
        entries = Array.new(20).to_h { |_| ["k_#{SecureRandom.hex(4)}", SecureRandom.hex(48)] }
        { "https://example.com" => entries }
      end
    end

    CURRENT_TARGET = Target.new(
      name: "bundle_codec",
      setup: -> { BundleCodecFixtures.build },
      measure: lambda do |ctx|
        blob = Browserctl::State::Bundle.encode(manifest: ctx[:manifest], payload: ctx[:payload])
        Browserctl::State::Bundle.decode(blob)
      end
    )
  end
end

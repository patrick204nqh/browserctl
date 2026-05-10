# frozen_string_literal: true

module Browserctl
  class Error < StandardError
    # Canonical enum of stable error code strings emitted on the wire and in
    # CLI stderr payloads. Codes are SCREAMING_SNAKE_CASE and must remain
    # stable across releases — agents branch on these deterministically.
    #
    # The full sweep that wires every raise site to one of these codes lands
    # in PR #8 of the v0.12 "Solid" milestone. This module is the single
    # source of truth those raises will reference.
    module Codes
      AUTH_REQUIRED            = "AUTH_REQUIRED"
      SELECTOR_NOT_FOUND       = "SELECTOR_NOT_FOUND"
      STATE_EXPIRED            = "STATE_EXPIRED"
      SECRET_RESOLUTION_FAILED = "SECRET_RESOLUTION_FAILED"
      DAEMON_UNREACHABLE       = "DAEMON_UNREACHABLE"
      PROTOCOL_MISMATCH        = "PROTOCOL_MISMATCH"
      DOMAIN_NOT_ALLOWED       = "DOMAIN_NOT_ALLOWED"
      KEY_NOT_FOUND            = "KEY_NOT_FOUND"
      GENERIC                  = "GENERIC"

      ALL = [
        AUTH_REQUIRED,
        SELECTOR_NOT_FOUND,
        STATE_EXPIRED,
        SECRET_RESOLUTION_FAILED,
        DAEMON_UNREACHABLE,
        PROTOCOL_MISMATCH,
        DOMAIN_NOT_ALLOWED,
        KEY_NOT_FOUND,
        GENERIC
      ].freeze

      def self.all
        ALL
      end

      def self.valid?(code)
        ALL.include?(code)
      end
    end
  end
end

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

      # Validation family — introduced in v0.14 WS-1 to retire the remaining
      # bare ArgumentError raises on public APIs and DSL guards.
      # VALIDATION_FAILED is the parent code; the four INVALID_* members are
      # specialisations that all share exit code 8. See docs/reference/errors.md
      # for the per-code triggers.
      VALIDATION_FAILED        = "VALIDATION_FAILED"
      INVALID_SELECTOR_REF     = "INVALID_SELECTOR_REF"
      INVALID_STATE_NAME       = "INVALID_STATE_NAME"
      INVALID_DSL_USAGE        = "INVALID_DSL_USAGE"
      INVALID_FORMAT_VERSION   = "INVALID_FORMAT_VERSION"

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
        VALIDATION_FAILED,
        INVALID_SELECTOR_REF,
        INVALID_STATE_NAME,
        INVALID_DSL_USAGE,
        INVALID_FORMAT_VERSION,
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

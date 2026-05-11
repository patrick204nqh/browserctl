# frozen_string_literal: true

require_relative "codes"

module Browserctl
  class Error < StandardError
    # Stable mapping from a canonical {Browserctl::Error::Codes} string to a
    # process exit status. The CLI's top-level rescue uses this so AI agents
    # and shell scripts can branch on `$?` deterministically without parsing
    # stderr.
    #
    # Stability contract:
    # - Exit code integers are part of the v0.12 stable surface and will not
    #   be renumbered without a major version bump.
    # - Unknown / unmapped codes intentionally fall through to {GENERIC} (1)
    #   so an unfamiliar code never silently surfaces as a non-error (0).
    #
    # See docs/reference/exit-codes.md for the operator-facing table.
    module ExitCodes
      OK                 = 0
      GENERIC            = 1
      DRIFT              = 2
      AUTH_REQUIRED      = 3
      DAEMON_UNREACHABLE = 4
      PROTOCOL_MISMATCH  = 5
      SELECTOR_NOT_FOUND = 6
      STATE_EXPIRED      = 7
      VALIDATION_FAILED  = 8

      # Canonical Codes string → exit status integer. Codes without an entry
      # (e.g. DOMAIN_NOT_ALLOWED, KEY_NOT_FOUND, SECRET_RESOLUTION_FAILED,
      # GENERIC) collapse to {GENERIC} for now; they may earn dedicated exit
      # codes in a future milestone.
      #
      # DRIFT (2) is reserved for a future Codes::DRIFT and currently has no
      # entry in this table — drift-related raises fall through to GENERIC
      # until that code is introduced.
      #
      # The validation family (VALIDATION_FAILED parent plus INVALID_*
      # specialisations) all map to exit code 8 — agents and scripts can
      # branch on `$? == 8` for any caller-side validation failure without
      # caring which specific guard tripped.
      TABLE = {
        Codes::AUTH_REQUIRED => AUTH_REQUIRED,
        Codes::DAEMON_UNREACHABLE => DAEMON_UNREACHABLE,
        Codes::PROTOCOL_MISMATCH => PROTOCOL_MISMATCH,
        Codes::SELECTOR_NOT_FOUND => SELECTOR_NOT_FOUND,
        Codes::STATE_EXPIRED => STATE_EXPIRED,
        Codes::VALIDATION_FAILED => VALIDATION_FAILED,
        Codes::INVALID_SELECTOR_REF => VALIDATION_FAILED,
        Codes::INVALID_STATE_NAME => VALIDATION_FAILED,
        Codes::INVALID_DSL_USAGE => VALIDATION_FAILED,
        Codes::INVALID_FORMAT_VERSION => VALIDATION_FAILED
      }.freeze

      # @param code [String, nil] a canonical code from {Browserctl::Error::Codes}
      # @return [Integer] mapped exit status; {GENERIC} for nil or unknown codes
      def self.for(code)
        return GENERIC if code.nil?

        TABLE.fetch(code, GENERIC)
      end
    end
  end
end

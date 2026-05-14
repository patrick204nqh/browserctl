# frozen_string_literal: true

require_relative "codes"

module Browserctl
  class Error < StandardError
    # Maps a stable error code (see {Browserctl::Error::Codes}) to a short
    # imperative sentence telling the operator (or AI agent) what to try
    # next. Codes without an explicit entry fall back to a generic pointer
    # to the error reference doc (added in PR #11 of v0.12).
    module SuggestedActions
      DEFAULT = "See docs/reference/errors.md for guidance."

      TABLE = {
        Codes::AUTH_REQUIRED =>
          "Run the suggested flow to refresh credentials, then retry.",
        Codes::SELECTOR_NOT_FOUND =>
          "Re-run snapshot to get fresh refs, then retry with a stable ref or selector.",
        Codes::STATE_EXPIRED =>
          "Re-save the state bundle (state save) or rotate it (state rotate).",
        Codes::SECRET_RESOLUTION_FAILED =>
          "Verify the secret resolver config and that the underlying secret exists.",
        Codes::DAEMON_UNREACHABLE =>
          "Start the daemon with 'browserctl daemon start', then retry.",
        Codes::PROTOCOL_MISMATCH =>
          "Upgrade browserctl to a version that supports this artifact's format version.",
        Codes::DOMAIN_NOT_ALLOWED =>
          "Add the domain to your policy allowlist or use an allowed URL.",
        Codes::KEY_NOT_FOUND =>
          "Verify the key was stored in this daemon session before fetching.",
        Codes::VALIDATION_FAILED =>
          "Check the argument or DSL usage against the documented contract, then retry.",
        Codes::INVALID_SELECTOR_REF =>
          "Pass either a CSS selector or a stable ref — one is required.",
        Codes::INVALID_STATE_NAME =>
          "Use only letters, digits, '_' or '-' (max 64 chars) for state names.",
        Codes::INVALID_DSL_USAGE =>
          "Check the workflow/flow DSL call against docs/reference/style-guide.md; " \
          "required blocks or arguments are missing.",
        Codes::INVALID_FORMAT_VERSION =>
          "Use a non-negative Integer for the format version header; see docs/reference/format-versions.md.",
        Codes::INVALID_ARGUMENT =>
          "Check the argument value against the documented contract; " \
          "e.g. --scope must be one of cookies|localStorage|sessionStorage.",
        Codes::PLUGIN_FAILED =>
          "Check the plugin's logs; the daemon caught an uncaught exception from the plugin and is otherwise healthy.",
        Codes::PLUGIN_TIMED_OUT =>
          "Increase the plugin's `timeout:` on register_command, or pass `timeout: nil` to opt out (not recommended).",
        Codes::GENERIC => DEFAULT
      }.freeze

      # @param code [String, nil] a SCREAMING_SNAKE code from {Codes}
      # @return [String] suggested action sentence; never nil
      def self.for(code)
        TABLE.fetch(code, DEFAULT)
      end
    end
  end
end

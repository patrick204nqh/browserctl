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

# frozen_string_literal: true

require "json"
require_relative "../errors"
require_relative "../error/suggested_actions"

module Browserctl
  module Commands
    module CliOutput
      AUTH_REQUIRED_EXIT_CODE = Browserctl::AuthRequiredError::AUTH_REQUIRED_EXIT_CODE

      def print_result(res)
        if res.is_a?(Hash) && (res[:error] || res["error"])
          message = res[:error] || res["error"]
          warn "Error: #{message}"
          warn structured_error_line(res, message)
          puts res.to_json
          exit exit_code_for(res)
        end
        puts res.to_json
      end

      # Maps a daemon error response onto a process exit code. Defaults to 1;
      # special-cased only for codes that callers programmatically branch on.
      def exit_code_for(res)
        return AUTH_REQUIRED_EXIT_CODE if (res[:code] || res["code"]) == "AUTH_REQUIRED"

        1
      end

      # Builds the single-line structured payload emitted to stderr after
      # the human-readable line. Agents parse this JSON deterministically.
      # Shape: { code, message, context, suggested_action }.
      def structured_error_line(res, message)
        code    = (res[:code] || res["code"] || Browserctl::Error::Codes::GENERIC).to_s
        context = res[:context] || res["context"] || {}
        action  = res[:suggested_action] || res["suggested_action"] ||
                  Browserctl::Error::SuggestedActions.for(code)
        JSON.generate(
          code: code,
          message: message,
          context: context,
          suggested_action: action
        )
      end
    end
  end
end

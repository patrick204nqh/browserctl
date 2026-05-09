# frozen_string_literal: true

require_relative "../errors"

module Browserctl
  module Commands
    module CliOutput
      AUTH_REQUIRED_EXIT_CODE = Browserctl::AuthRequiredError::AUTH_REQUIRED_EXIT_CODE

      def print_result(res)
        if res.is_a?(Hash) && (res[:error] || res["error"])
          warn "Error: #{res[:error] || res['error']}"
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
    end
  end
end

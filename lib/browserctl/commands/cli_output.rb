# frozen_string_literal: true

module Browserctl
  module Commands
    module CliOutput
      def print_result(res)
        if res.is_a?(Hash) && res[:error]
          warn "Error: #{res[:error]}"
          exit 1
        end
        puts res.to_json
      end
    end
  end
end

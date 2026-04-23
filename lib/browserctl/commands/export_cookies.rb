# frozen_string_literal: true

module Browserctl
  module Commands
    class ExportCookies
      def self.run(client, args)
        page = args.shift or abort "usage: browserctl export-cookies <page> <path>"
        path = args.shift or abort "usage: browserctl export-cookies <page> <path>"
        result = client.export_cookies(page, path)
        if result[:error]
          warn "Error: #{result[:error]}"
          exit 1
        end
        puts result.to_json
      end
    end
  end
end

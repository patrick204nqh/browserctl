# frozen_string_literal: true

module Browserctl
  module Commands
    class ImportCookies
      def self.run(client, args)
        page = args.shift or abort "usage: browserctl import-cookies <page> <path>"
        path = args.shift or abort "usage: browserctl import-cookies <page> <path>"
        begin
          result = client.import_cookies(page, path)
        rescue => e
          warn "Error: #{e.message}"
          exit 1
        end
        if result[:error]
          warn "Error: #{result[:error]}"
          exit 1
        end
        puts result.to_json
      end
    end
  end
end

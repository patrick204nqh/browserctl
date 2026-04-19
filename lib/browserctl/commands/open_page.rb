# frozen_string_literal: true

require_relative "option_parser"

module Browserctl
  module Commands
    class OpenPage
      def self.run(client, args)
        name = args.shift or abort "usage: browserctl open <name> [--url URL]"
        url  = OptionParser.extract_opt(args, "--url")
        res  = client.open_page(name, url: url)
        puts res.to_json
      end
    end
  end
end

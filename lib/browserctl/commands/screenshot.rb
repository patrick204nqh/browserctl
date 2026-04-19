# frozen_string_literal: true

require_relative "option_parser"

module Browserctl
  module Commands
    class Screenshot
      def self.run(client, args)
        name = args.shift or abort "usage: browserctl shot <page> [--out PATH] [--full]"
        path = OptionParser.extract_opt(args, "--out")
        full = args.delete("--full") ? true : false
        puts client.screenshot(name, path: path, full: full).to_json
      end
    end
  end
end

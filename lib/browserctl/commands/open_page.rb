# frozen_string_literal: true

require "optimist"
require_relative "cli_output"

module Browserctl
  module Commands
    class OpenPage
      extend CliOutput

      def self.run(client, args)
        opts = Optimist.options(args) do
          banner "Usage: browserctl open <page> [--url URL]"
          opt :url, "URL to navigate to", type: :string, short: "-u"
        end
        name = args.shift or abort "usage: browserctl open <page> [--url URL]"
        print_result(client.open_page(name, url: opts[:url]))
      end
    end
  end
end

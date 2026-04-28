# frozen_string_literal: true

require "optimist"
require_relative "cli_output"

module Browserctl
  module Commands
    class Screenshot
      extend CliOutput

      def self.run(client, args)
        opts = Optimist.options(args) do
          banner "Usage: browserctl screenshot <page> [--out PATH] [--full]"
          opt :out,  "Output file path",   type: :string, short: "-o"
          opt :full, "Capture full page",  default: false, short: "-f"
        end
        name = args.shift or abort "usage: browserctl screenshot <page> [--out PATH] [--full]"
        print_result(client.screenshot(name, path: opts[:out], full: opts[:full]))
      end
    end
  end
end

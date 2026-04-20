# frozen_string_literal: true

require "optimist"
require_relative "cli_output"

module Browserctl
  module Commands
    class Click
      extend CliOutput

      def self.run(client, args)
        opts = Optimist.options(args) do
          banner "Usage: browserctl click <page> <selector>\n       " \
                 "browserctl click <page> --ref <ref>"
          opt :ref, "Snapshot ref to click", type: :string, short: "-r"
        end
        name = args.shift
        if opts[:ref]
          abort "usage: browserctl click <page> --ref <ref>" unless name
          print_result(client.click(name, ref: opts[:ref]))
        else
          selector = args.shift
          abort "usage: browserctl click <page> <selector>" unless name && selector
          print_result(client.click(name, selector))
        end
      end
    end
  end
end

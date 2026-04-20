# frozen_string_literal: true

require "optimist"
require_relative "cli_output"

module Browserctl
  module Commands
    class Fill
      extend CliOutput

      def self.run(client, args)
        opts = Optimist.options(args) do
          banner "Usage: browserctl fill <page> <selector> <value>\n       " \
                 "browserctl fill <page> --ref <ref> --value <value>"
          opt :ref,   "Snapshot ref to fill", type: :string, short: "-r"
          opt :value, "Value to fill",        type: :string, short: "-V"
        end
        name = args.shift
        opts[:ref] ? fill_by_ref(client, name, opts) : fill_by_selector(client, name, args, opts[:value])
      end

      class << self
        private

        def fill_by_ref(client, name, opts)
          abort "usage: browserctl fill <page> --ref <ref> --value <value>" unless name && opts[:value]
          print_result(client.fill(name, nil, opts[:value], ref: opts[:ref]))
        end

        def fill_by_selector(client, name, args, value_opt)
          selector = args.shift
          value    = value_opt || args.shift
          abort "usage: browserctl fill <page> <selector> <value>" unless name && selector && value
          print_result(client.fill(name, selector, value))
        end
      end
    end
  end
end

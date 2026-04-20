# frozen_string_literal: true

require "optimist"
require_relative "cli_output"

module Browserctl
  module Commands
    class Watch
      extend CliOutput

      def self.run(client, args)
        opts = Optimist.options(args) do
          banner "Usage: browserctl watch <page> <selector> [--timeout N]"
          opt :timeout, "Seconds to wait (default: 30)", default: 30.0, short: "-t"
        end
        name     = args.shift
        selector = args.shift
        abort "usage: browserctl watch <page> <selector> [--timeout N]" unless name && selector
        unless opts[:timeout].positive?
          warn "Error: --timeout must be a positive number"
          exit 1
        end
        print_result(client.watch(name, selector, timeout: opts[:timeout]))
      end
    end
  end
end

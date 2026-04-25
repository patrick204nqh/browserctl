# frozen_string_literal: true

require "json"
require "optimist"

module Browserctl
  module Commands
    class Snapshot
      VALID_FORMATS = %w[elements html].freeze

      def self.run(client, args)
        opts = Optimist.options(args) do
          banner "Usage: browserctl snap <page> [--format elements|html] [--diff]"
          opt :format, "Output format: elements (default) or html", default: "elements", short: "-f"
          opt :diff,   "Return only changed elements", default: false, short: "-d"
        end
        name = args.shift or abort "usage: browserctl snap <page> [--format elements|html] [--diff]"
        unless VALID_FORMATS.include?(opts[:format])
          warn "Error: --format must be one of: #{VALID_FORMATS.join(', ')}"
          exit 1
        end
        res = client.snapshot(name, format: opts[:format], diff: opts[:diff])
        output_snapshot(res, opts[:format])
      end

      class << self
        private

        def output_snapshot(res, format)
          if res[:error]
            warn "Error: #{res[:error]}"
            exit 1
          end
          puts(format == "elements" ? JSON.pretty_generate(res[:snapshot]) : res[:html])
        end
      end
    end
  end
end

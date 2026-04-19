# frozen_string_literal: true

require "json"
require_relative "option_parser"

module Browserctl
  module Commands
    class Snapshot
      def self.run(client, args)
        name   = args.shift or abort "usage: browserctl snapshot <page> [--format ai|html]"
        format = OptionParser.extract_opt(args, "--format") || "ai"
        res    = client.snapshot(name, format: format)
        output_snapshot(res, format)
      end

      def self.output_snapshot(res, format)
        return abort res[:error] if res[:error]

        format == "ai" ? puts(JSON.pretty_generate(res[:snapshot])) : puts(res[:html])
      end
    end
  end
end

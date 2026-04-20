# frozen_string_literal: true

require "json"
require_relative "flag_extractor"

module Browserctl
  module Commands
    class Snapshot
      def self.run(client, args)
        name   = args.shift or abort "usage: browserctl snap <page> [--format ai|html] [--diff]"
        format = FlagExtractor.extract_opt(args, "--format") || "ai"
        diff   = FlagExtractor.extract_flag(args, "--diff")
        res    = client.snapshot(name, format: format, diff: diff)
        output_snapshot(res, format)
      end

      class << self
        private

        def output_snapshot(res, format)
          return abort res[:error] if res[:error]

          puts(format == "ai" ? JSON.pretty_generate(res[:snapshot]) : res[:html])
        end
      end
    end
  end
end

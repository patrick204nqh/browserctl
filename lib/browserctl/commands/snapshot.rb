# frozen_string_literal: true

require "json"
require_relative "flag_extractor"

module Browserctl
  module Commands
    class Snapshot
      def self.run(client, args)
        name   = args.shift or abort "usage: browserctl snapshot <page> [--format ai|html]"
        format = FlagExtractor.extract_opt(args, "--format") || "ai"
        res    = client.snapshot(name, format: format)
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

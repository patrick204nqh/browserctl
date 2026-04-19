# frozen_string_literal: true

require "json"

module Browserctl
  module Commands
    class Snapshot
      def self.run(client, args)
        name   = args.shift or abort "usage: browserctl snapshot <page> [--format ai|html]"
        format = extract_opt(args, "--format") || "ai"
        res    = client.snapshot(name, format: format)
        if res[:error]
          abort res[:error]
        elsif format == "ai"
          puts JSON.pretty_generate(res[:snapshot])
        else
          puts res[:html]
        end
      end

      def self.extract_opt(args, flag)
        i = args.index(flag)
        return unless i

        args.delete_at(i)
        args.delete_at(i)
      end
    end
  end
end

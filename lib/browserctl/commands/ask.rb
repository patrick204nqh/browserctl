# frozen_string_literal: true

require_relative "cli_output"

module Browserctl
  module Commands
    module Ask
      extend CliOutput

      def self.run(args)
        abort "usage: browserctl ask <prompt>" if args.empty?

        prompt = args.join(" ")
        $stderr.print("[browserctl] #{prompt} ")
        value = $stdin.gets.chomp
        print_result({ ok: true, value: value })
      end
    end
  end
end

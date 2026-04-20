# frozen_string_literal: true

require_relative "flag_extractor"

module Browserctl
  module Commands
    class Watch
      def self.run(client, args)
        name     = args.shift
        selector = args.shift
        timeout  = (FlagExtractor.extract_opt(args, "--timeout") || 30).to_f
        abort "usage: browserctl watch <page> <selector> [--timeout N]" unless name && selector
        puts client.watch(name, selector, timeout: timeout).to_json
      end
    end
  end
end

# frozen_string_literal: true

require_relative "flag_extractor"

module Browserctl
  module Commands
    class Click
      def self.run(client, args)
        name = args.shift
        ref  = FlagExtractor.extract_opt(args, "--ref")
        selector = args.shift unless ref

        if ref
          abort "usage: browserctl click <page> --ref <ref>" unless name
          puts client.click(name, ref: ref).to_json
        else
          abort "usage: browserctl click <page> <selector>" unless name && selector
          puts client.click(name, selector).to_json
        end
      end
    end
  end
end

# frozen_string_literal: true

require_relative "flag_extractor"

module Browserctl
  module Commands
    class Fill
      def self.run(client, args)
        name = args.shift
        ref  = FlagExtractor.extract_opt(args, "--ref")

        if ref
          value = FlagExtractor.extract_opt(args, "--value")
          abort "usage: browserctl fill <page> --ref <ref> --value <value>" unless name && value
          puts client.fill(name, nil, value, ref: ref).to_json
        else
          selector = args.shift
          value = args.shift
          abort "usage: browserctl fill <page> <selector> <value>" unless name && selector && value
          puts client.fill(name, selector, value).to_json
        end
      end
    end
  end
end

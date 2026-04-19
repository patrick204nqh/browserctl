# frozen_string_literal: true

module Browserctl
  module Commands
    module FlagExtractor
      def self.extract_opt(args, flag)
        i = args.index(flag)
        return unless i

        args.delete_at(i)
        args.delete_at(i)
      end
    end
  end
end

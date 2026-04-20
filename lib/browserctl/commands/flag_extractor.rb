# frozen_string_literal: true

module Browserctl
  module Commands
    module FlagExtractor
      def self.extract_opt(args, flag)
        i = args.index(flag)
        return unless i

        sliced = args.slice!(i, 2)
        sliced.length == 2 ? sliced.last : nil
      end

      def self.extract_flag?(args, flag)
        i = args.index(flag)
        return false unless i

        args.delete_at(i)
        true
      end
    end
  end
end

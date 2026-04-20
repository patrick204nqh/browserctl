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

      def self.extract_flag(args, flag)
        i = args.index(flag)
        return false unless i
        args.delete_at(i)
        true
      end
    end
  end
end

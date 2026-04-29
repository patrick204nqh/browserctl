# frozen_string_literal: true

require "open3"

module Browserctl
  module SecretResolvers
    class OnePassword < Base
      def self.scheme = "op"

      def available?
        system("which op > /dev/null 2>&1")
      end

      def resolve(reference)
        result, status = Open3.capture2("op", "read", "op://#{reference}")
        raise SecretResolverError, "1Password item not found: op://#{reference}" unless status.success?

        result.chomp
      end
    end
  end
end

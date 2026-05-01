# frozen_string_literal: true

require "open3"

module Browserctl
  module SecretResolvers
    class OnePassword < Base
      def self.scheme = "op"

      def available?
        system("which", "op", out: File::NULL, err: File::NULL)
      end

      SAFE_REFERENCE = %r{\A[a-zA-Z0-9._\-/]+\z}

      def resolve(reference)
        unless SAFE_REFERENCE.match?(reference)
          raise SecretResolverError, "invalid 1Password reference format: #{reference.inspect}"
        end

        result, status = Open3.capture2("op", "read", "op://#{reference}")
        raise SecretResolverError, "1Password item not found: op://#{reference}" unless status.success?

        result.chomp
      end
    end
  end
end

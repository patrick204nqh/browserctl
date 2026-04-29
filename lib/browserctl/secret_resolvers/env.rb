# frozen_string_literal: true

module Browserctl
  module SecretResolvers
    class Env < Base
      def self.scheme = "env"

      def resolve(reference)
        ENV.fetch(reference) { raise SecretResolverError, "env var '#{reference}' is not set" }
      end
    end
  end
end

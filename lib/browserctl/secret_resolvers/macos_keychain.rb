# frozen_string_literal: true

require "open3"

module Browserctl
  module SecretResolvers
    class MacOSKeychain < Base
      def self.scheme = "keychain"

      def available?
        RUBY_PLATFORM.include?("darwin") && system("which security > /dev/null 2>&1")
      end

      def resolve(reference)
        service, account = reference.split("/", 2)
        if account.nil?
          raise SecretResolverError,
                "keychain reference must be 'service/account', got: #{reference.inspect}"
        end

        result, status = Open3.capture2("security", "find-generic-password",
                                        "-a", account, "-s", service, "-w")
        raise SecretResolverError, "keychain item not found: #{reference}" unless status.success?

        result.chomp
      end
    end
  end
end

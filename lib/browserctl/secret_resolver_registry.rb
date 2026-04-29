# frozen_string_literal: true

require_relative "errors"

module Browserctl
  class SecretResolverRegistry
    @mutex    = Mutex.new
    @registry = {}

    def self.register(resolver_class)
      instance = resolver_class.new
      @mutex.synchronize { @registry[resolver_class.scheme] = instance }
    end

    def self.resolve(secret_ref)
      scheme, reference = secret_ref.split("://", 2)
      resolver = @mutex.synchronize { @registry[scheme] }
      raise SecretResolverError, "unknown secret resolver scheme '#{scheme}'" unless resolver

      unless resolver.available?
        msg = "'#{scheme}://' resolver is not available in this environment"
        if scheme == "keychain"
          msg += "\n  Use env://YOUR_VAR_NAME to source secrets from environment variables instead."
        end
        raise SecretResolverError, msg
      end

      resolver.resolve(reference)
    rescue SecretResolverError
      raise
    rescue StandardError => e
      raise SecretResolverError, "secret resolution failed for #{secret_ref.inspect}: #{e.message}"
    end

    def self.registered?(scheme)
      @mutex.synchronize { @registry.key?(scheme) }
    end

    def self.reset!
      @mutex.synchronize { @registry.clear }
    end
  end
end

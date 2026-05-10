# frozen_string_literal: true

require_relative "errors"

module Browserctl
  class SecretResolverRegistry
    @mutex          = Mutex.new
    @registry       = {}
    @resolved_values = []

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

      value = resolver.resolve(reference)
      record_resolved_value(value)
      value
    rescue SecretResolverError
      raise
    rescue StandardError => e
      raise SecretResolverError, "secret resolution failed for #{secret_ref.inspect}: #{e.message}"
    end

    def self.registered?(scheme)
      @mutex.synchronize { @registry.key?(scheme) }
    end

    # In-memory record of values resolved during this process. Used by the
    # Redactor so trace output never leaks values that flowed through the
    # registry. Never persisted.
    def self.resolved_values
      @mutex.synchronize { @resolved_values.dup }
    end

    def self.record_resolved_value(value)
      return unless value.is_a?(String) && !value.empty?

      @mutex.synchronize { @resolved_values << value unless @resolved_values.include?(value) }
    end

    def self.reset!
      @mutex.synchronize do
        @registry.clear
        @resolved_values.clear
      end
    end
  end
end

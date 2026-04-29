# frozen_string_literal: true

require_relative "secret_resolver_registry"
require_relative "secret_resolvers/base"
require_relative "secret_resolvers/env"
require_relative "secret_resolvers/macos_keychain"
require_relative "secret_resolvers/one_password"

Browserctl::SecretResolverRegistry.register(Browserctl::SecretResolvers::Env)
Browserctl::SecretResolverRegistry.register(Browserctl::SecretResolvers::MacOSKeychain)
Browserctl::SecretResolverRegistry.register(Browserctl::SecretResolvers::OnePassword)

user_resolvers = File.expand_path("~/.browserctl/resolvers.rb")
load user_resolvers if File.exist?(user_resolvers)

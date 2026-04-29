# frozen_string_literal: true

require "spec_helper"

RSpec.describe Browserctl::SecretResolverRegistry do
  before { described_class.reset! }
  after  { described_class.reset! }

  let(:resolver_class) do
    Class.new(Browserctl::SecretResolvers::Base) do
      def self.scheme = "test"
      def resolve(reference) = "resolved:#{reference}"
    end
  end

  let(:unavailable_resolver_class) do
    Class.new(Browserctl::SecretResolvers::Base) do
      def self.scheme = "unavail"
      def available? = false
      def resolve(_reference) = "should not reach"
    end
  end

  let(:raising_resolver_class) do
    Class.new(Browserctl::SecretResolvers::Base) do
      def self.scheme = "raises"
      def resolve(_reference) = raise("unexpected failure")
    end
  end

  describe ".register" do
    it "stores resolver by scheme" do
      described_class.register(resolver_class)
      expect(described_class.registered?("test")).to be true
    end
  end

  describe ".resolve" do
    it "dispatches to the right resolver" do
      described_class.register(resolver_class)
      expect(described_class.resolve("test://my-var")).to eq("resolved:my-var")
    end

    it "raises SecretResolverError for unknown scheme" do
      expect { described_class.resolve("unknown://foo") }
        .to raise_error(Browserctl::SecretResolverError, /unknown secret resolver scheme 'unknown'/)
    end

    it "raises SecretResolverError when available? returns false" do
      described_class.register(unavailable_resolver_class)
      expect { described_class.resolve("unavail://foo") }
        .to raise_error(Browserctl::SecretResolverError, %r{'unavail://' resolver is not available})
    end

    it "includes env:// hint when keychain:// resolver is unavailable" do
      keychain_class = Class.new(Browserctl::SecretResolvers::Base) do
        def self.scheme = "keychain"
        def available? = false
        def resolve(_reference) = "nope"
      end
      described_class.register(keychain_class)
      expect { described_class.resolve("keychain://MyApp/admin") }
        .to raise_error(Browserctl::SecretResolverError, %r{Use env://YOUR_VAR_NAME})
    end

    it "wraps non-SecretResolverError in SecretResolverError" do
      described_class.register(raising_resolver_class)
      expect { described_class.resolve("raises://something") }
        .to raise_error(Browserctl::SecretResolverError, %r{secret resolution failed for "raises://something"})
    end
  end
end

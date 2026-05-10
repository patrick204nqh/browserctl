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

    it "carries SECRET_RESOLUTION_FAILED code for unknown scheme" do
      expect { described_class.resolve("unknown://foo") }
        .to raise_error(Browserctl::SecretResolverError) do |e|
          expect(e.code).to eq(Browserctl::Error::Codes::SECRET_RESOLUTION_FAILED)
        end
    end

    it "carries SECRET_RESOLUTION_FAILED code when wrapping unexpected errors" do
      described_class.register(raising_resolver_class)
      expect { described_class.resolve("raises://x") }
        .to raise_error(Browserctl::SecretResolverError) do |e|
          expect(e.code).to eq(Browserctl::Error::Codes::SECRET_RESOLUTION_FAILED)
        end
    end

    it "treats a reference with no scheme separator as an unknown scheme" do
      # When `secret_ref` has no `://`, split returns [ref, nil] and the
      # registry will look up the resolver under the full string.
      expect { described_class.resolve("no-scheme-here") }
        .to raise_error(Browserctl::SecretResolverError, /unknown secret resolver scheme/)
    end
  end

  describe ".registered?" do
    it "returns false for an unregistered scheme" do
      expect(described_class.registered?("nope")).to be false
    end
  end

  describe "resolved-value instrumentation" do
    it "records the resolved value so the redactor can scrub it from traces" do
      described_class.register(resolver_class)
      described_class.resolve("test://alpha")
      expect(described_class.resolved_values).to include("resolved:alpha")
    end

    it "deduplicates repeated resolutions of the same value" do
      described_class.register(resolver_class)
      3.times { described_class.resolve("test://same") }
      expect(described_class.resolved_values.count("resolved:same")).to eq(1)
    end

    it "does not record empty strings" do
      empty_class = Class.new(Browserctl::SecretResolvers::Base) do
        def self.scheme = "empty"
        def resolve(_reference) = ""
      end
      described_class.register(empty_class)
      described_class.resolve("empty://nothing")
      expect(described_class.resolved_values).not_to include("")
    end

    it "does not record non-string values" do
      numeric_class = Class.new(Browserctl::SecretResolvers::Base) do
        def self.scheme = "numeric"
        def resolve(_reference) = 42
      end
      described_class.register(numeric_class)
      described_class.resolve("numeric://foo")
      expect(described_class.resolved_values).to be_empty
    end

    it "returns a copy so callers cannot mutate internal state" do
      described_class.register(resolver_class)
      described_class.resolve("test://copy")
      described_class.resolved_values << "leaked"
      expect(described_class.resolved_values).not_to include("leaked")
    end

    it "clears recorded values on reset!" do
      described_class.register(resolver_class)
      described_class.resolve("test://x")
      expect(described_class.resolved_values).not_to be_empty
      described_class.reset!
      expect(described_class.resolved_values).to be_empty
    end
  end

  describe "thread safety" do
    it "does not double-record when many threads resolve the same key" do
      described_class.register(resolver_class)
      threads = Array.new(20) do
        Thread.new { described_class.resolve("test://shared") }
      end
      threads.each(&:join)
      expect(described_class.resolved_values.count("resolved:shared")).to eq(1)
    end

    it "records distinct values from concurrent resolutions" do
      described_class.register(resolver_class)
      threads = 10.times.map do |i|
        Thread.new { described_class.resolve("test://k#{i}") }
      end
      threads.each(&:join)
      10.times do |i|
        expect(described_class.resolved_values).to include("resolved:k#{i}")
      end
    end
  end
end

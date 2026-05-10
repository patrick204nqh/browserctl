# frozen_string_literal: true

require "spec_helper"

RSpec.describe Browserctl::SecretResolvers::Env do
  subject(:resolver) { described_class.new }

  describe "#available?" do
    it "returns true" do
      expect(resolver.available?).to be true
    end
  end

  describe "#resolve" do
    it "resolves an existing env var" do
      ENV["BCTL_TEST_VAR"] = "secret_value"
      expect(resolver.resolve("BCTL_TEST_VAR")).to eq("secret_value")
    ensure
      ENV.delete("BCTL_TEST_VAR")
    end

    it "raises SecretResolverError when var is not set" do
      ENV.delete("BCTL_MISSING_VAR")
      expect { resolver.resolve("BCTL_MISSING_VAR") }
        .to raise_error(Browserctl::SecretResolverError, /env var 'BCTL_MISSING_VAR' is not set/)
    end

    it "raises with code SECRET_RESOLUTION_FAILED when var is not set" do
      ENV.delete("BCTL_MISSING_VAR")
      expect { resolver.resolve("BCTL_MISSING_VAR") }
        .to raise_error(Browserctl::SecretResolverError) do |e|
          expect(e.code).to eq(Browserctl::Error::Codes::SECRET_RESOLUTION_FAILED)
        end
    end

    it "resolves an env var whose value is empty string" do
      ENV["BCTL_EMPTY_VAR"] = ""
      expect(resolver.resolve("BCTL_EMPTY_VAR")).to eq("")
    ensure
      ENV.delete("BCTL_EMPTY_VAR")
    end

    it "raises SecretResolverError when reference is empty" do
      ENV.delete("")
      expect { resolver.resolve("") }
        .to raise_error(Browserctl::SecretResolverError)
    end
  end
end

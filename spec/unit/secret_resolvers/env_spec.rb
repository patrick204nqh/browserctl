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
  end
end

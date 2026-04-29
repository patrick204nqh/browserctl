# frozen_string_literal: true

require "spec_helper"

RSpec.describe Browserctl::SecretResolvers::MacOSKeychain do
  subject(:resolver) { described_class.new }

  describe "#available?" do
    it "returns false on non-darwin" do
      stub_const("RUBY_PLATFORM", "x86_64-linux")
      expect(resolver.available?).to be false
    end
  end

  describe "#resolve" do
    it "raises SecretResolverError on malformed reference (no /)" do
      expect { resolver.resolve("no-slash") }
        .to raise_error(Browserctl::SecretResolverError, /keychain reference must be 'service\/account'/)
    end

    context "when security command fails" do
      it "raises SecretResolverError" do
        status = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture2).and_return(["", status])

        expect { resolver.resolve("my-service/my-account") }
          .to raise_error(Browserctl::SecretResolverError, /keychain item not found: my-service\/my-account/)
      end
    end

    context "when security command succeeds" do
      it "returns the value with trailing newline chomped" do
        status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture2).and_return(["my-password\n", status])

        expect(resolver.resolve("my-service/my-account")).to eq("my-password")
      end
    end
  end
end

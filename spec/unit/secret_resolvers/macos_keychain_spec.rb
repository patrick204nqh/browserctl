# frozen_string_literal: true

require "spec_helper"

RSpec.describe Browserctl::SecretResolvers::MacOSKeychain do
  subject(:resolver) { described_class.new }

  describe "#available?" do
    it "returns false on non-darwin" do
      stub_const("RUBY_PLATFORM", "x86_64-linux")
      expect(resolver.available?).to be false
    end

    it "returns true on darwin when `security` exists in PATH" do
      stub_const("RUBY_PLATFORM", "x86_64-darwin23")
      allow(resolver).to receive(:system)
        .with("which", "security", out: File::NULL, err: File::NULL).and_return(true)
      expect(resolver.available?).to be true
    end

    it "returns false on darwin when `security` is missing" do
      stub_const("RUBY_PLATFORM", "x86_64-darwin23")
      allow(resolver).to receive(:system)
        .with("which", "security", out: File::NULL, err: File::NULL).and_return(false)
      expect(resolver.available?).to be false
    end
  end

  describe "#resolve" do
    it "raises SecretResolverError on malformed reference (no /)" do
      expect { resolver.resolve("no-slash") }
        .to raise_error(Browserctl::SecretResolverError, %r{keychain reference must be 'service/account'})
    end

    context "when security command fails" do
      it "raises SecretResolverError" do
        status = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture2).and_return(["", status])

        expect { resolver.resolve("my-service/my-account") }
          .to raise_error(Browserctl::SecretResolverError, %r{keychain item not found: my-service/my-account})
      end
    end

    context "when security command succeeds" do
      it "returns the value with trailing newline chomped" do
        status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture2).and_return(["my-password\n", status])

        expect(resolver.resolve("my-service/my-account")).to eq("my-password")
      end
    end

    it "raises with SECRET_RESOLUTION_FAILED code on malformed reference" do
      expect { resolver.resolve("just-service") }
        .to raise_error(Browserctl::SecretResolverError) do |e|
          expect(e.code).to eq(Browserctl::Error::Codes::SECRET_RESOLUTION_FAILED)
        end
    end

    it "raises SecretResolverError on empty reference" do
      expect { resolver.resolve("") }
        .to raise_error(Browserctl::SecretResolverError)
    end

    it "carries SECRET_RESOLUTION_FAILED code when keychain lookup fails" do
      status = instance_double(Process::Status, success?: false)
      allow(Open3).to receive(:capture2).and_return(["", status])

      expect { resolver.resolve("svc/acct") }
        .to raise_error(Browserctl::SecretResolverError) do |e|
          expect(e.code).to eq(Browserctl::Error::Codes::SECRET_RESOLUTION_FAILED)
        end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe Browserctl::SecretResolvers::OnePassword do
  subject(:resolver) { described_class.new }

  describe "#available?" do
    it "returns false when op is not in PATH" do
      allow(resolver).to receive(:system).with("which", "op", out: File::NULL, err: File::NULL).and_return(false)
      expect(resolver.available?).to be false
    end

    it "returns true when op is in PATH" do
      allow(resolver).to receive(:system).with("which", "op", out: File::NULL, err: File::NULL).and_return(true)
      expect(resolver.available?).to be true
    end
  end

  describe "#resolve" do
    context "when op command fails" do
      it "raises SecretResolverError" do
        status = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture2).and_return(["", status])

        expect { resolver.resolve("vault/item/field") }
          .to raise_error(Browserctl::SecretResolverError, %r{1Password item not found: op://vault/item/field})
      end
    end

    context "when op command succeeds" do
      it "returns the value and chomps trailing newline" do
        status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture2).and_return(["super-secret\n", status])

        expect(resolver.resolve("vault/item/field")).to eq("super-secret")
      end
    end

    it "rejects references with shell metacharacters" do
      expect { resolver.resolve("vault/item; rm -rf /") }
        .to raise_error(Browserctl::SecretResolverError, /invalid 1Password reference format/)
    end

    it "rejects references with spaces" do
      expect { resolver.resolve("vault/item with space/field") }
        .to raise_error(Browserctl::SecretResolverError, /invalid 1Password reference format/)
    end

    it "rejects an empty reference" do
      expect { resolver.resolve("") }
        .to raise_error(Browserctl::SecretResolverError, /invalid 1Password reference format/)
    end

    it "carries SECRET_RESOLUTION_FAILED code on invalid reference" do
      expect { resolver.resolve("bad ref!") }
        .to raise_error(Browserctl::SecretResolverError) do |e|
          expect(e.code).to eq(Browserctl::Error::Codes::SECRET_RESOLUTION_FAILED)
        end
    end

    it "carries SECRET_RESOLUTION_FAILED code when op exits non-zero" do
      status = instance_double(Process::Status, success?: false)
      allow(Open3).to receive(:capture2).and_return(["", status])
      expect { resolver.resolve("vault/item/field") }
        .to raise_error(Browserctl::SecretResolverError) do |e|
          expect(e.code).to eq(Browserctl::Error::Codes::SECRET_RESOLUTION_FAILED)
        end
    end
  end
end

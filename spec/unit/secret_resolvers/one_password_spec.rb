# frozen_string_literal: true

require "spec_helper"

RSpec.describe Browserctl::SecretResolvers::OnePassword do
  subject(:resolver) { described_class.new }

  describe "#available?" do
    it "returns false when op is not in PATH" do
      allow(resolver).to receive(:system).with("which op > /dev/null 2>&1").and_return(false)
      expect(resolver.available?).to be false
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
  end
end

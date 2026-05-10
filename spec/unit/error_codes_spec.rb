# frozen_string_literal: true

require "spec_helper"
require "browserctl/errors"

RSpec.describe Browserctl::Error::Codes do
  describe "constants" do
    it "exposes every canonical v0.12 code as a frozen string" do
      {
        AUTH_REQUIRED:            "AUTH_REQUIRED",
        SELECTOR_NOT_FOUND:       "SELECTOR_NOT_FOUND",
        STATE_EXPIRED:            "STATE_EXPIRED",
        SECRET_RESOLUTION_FAILED: "SECRET_RESOLUTION_FAILED",
        DAEMON_UNREACHABLE:       "DAEMON_UNREACHABLE",
        PROTOCOL_MISMATCH:        "PROTOCOL_MISMATCH"
      }.each do |const, value|
        actual = described_class.const_get(const)
        expect(actual).to eq(value)
        expect(actual).to be_frozen
      end
    end
  end

  describe ".all" do
    it "returns the full frozen set of codes" do
      expect(described_class.all).to contain_exactly(
        "AUTH_REQUIRED",
        "SELECTOR_NOT_FOUND",
        "STATE_EXPIRED",
        "SECRET_RESOLUTION_FAILED",
        "DAEMON_UNREACHABLE",
        "PROTOCOL_MISMATCH"
      )
      expect(described_class.all).to be_frozen
    end
  end

  describe ".valid?" do
    it "accepts every enum member" do
      described_class.all.each do |code|
        expect(described_class.valid?(code)).to be(true)
      end
    end

    it "rejects unknown codes" do
      expect(described_class.valid?("NOT_A_REAL_CODE")).to be(false)
      expect(described_class.valid?(nil)).to be(false)
      expect(described_class.valid?("")).to be(false)
      expect(described_class.valid?("auth_required")).to be(false) # case-sensitive
    end
  end
end

RSpec.describe Browserctl::Error, "code: kwarg integration" do
  it "stores and exposes a canonical code passed to the base initializer" do
    err = described_class.new(
      "auth required",
      code: Browserctl::Error::Codes::AUTH_REQUIRED
    )
    expect(err.code).to eq("AUTH_REQUIRED")
    expect(err.message).to eq("auth required")
    expect(Browserctl::Error::Codes.valid?(err.code)).to be(true)
  end

  it "still defaults to the class default_code when no code is supplied" do
    expect(Browserctl::PageNotFound.new("x").code).to eq("page_not_found")
  end
end

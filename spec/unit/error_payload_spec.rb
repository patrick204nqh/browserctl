# frozen_string_literal: true

require "spec_helper"
require "browserctl/errors"

RSpec.describe Browserctl::Error, "#to_payload" do
  it "returns the canonical four-key structured payload" do
    err = Browserctl::SelectorNotFound.new("selector not found: .x", context: { selector: ".x" })
    expect(err.to_payload).to eq(
      code: Browserctl::Error::Codes::SELECTOR_NOT_FOUND,
      message: "selector not found: .x",
      context: { selector: ".x" },
      suggested_action: Browserctl::Error::SuggestedActions.for(Browserctl::Error::Codes::SELECTOR_NOT_FOUND)
    )
  end

  it "defaults context to an empty hash" do
    err = Browserctl::SelectorNotFound.new("x")
    expect(err.to_payload[:context]).to eq({})
  end

  it "uses the default fallback action for unknown codes" do
    err = Browserctl::Error.new("oops", code: "TOTALLY_MADE_UP")
    expect(err.to_payload[:suggested_action]).to eq(Browserctl::Error::SuggestedActions::DEFAULT)
  end
end

RSpec.describe Browserctl::Error::SuggestedActions do
  it "returns a non-empty imperative sentence for every enum code" do
    Browserctl::Error::Codes::ALL.each do |code|
      action = described_class.for(code)
      expect(action).to be_a(String)
      expect(action).not_to be_empty
    end
  end

  it "falls back to DEFAULT for unknown codes" do
    expect(described_class.for("NOT_A_REAL_CODE")).to eq(described_class::DEFAULT)
  end

  it "returns the AUTH_REQUIRED action verbatim" do
    expect(described_class.for(Browserctl::Error::Codes::AUTH_REQUIRED))
      .to match(/refresh credentials/i)
  end
end

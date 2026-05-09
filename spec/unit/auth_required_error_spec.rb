# frozen_string_literal: true

require "browserctl/errors"

RSpec.describe Browserctl::AuthRequiredError do
  it "carries AUTH_REQUIRED as its code" do
    expect(described_class.default_code).to eq("AUTH_REQUIRED")
    expect(described_class.new.code).to eq("AUTH_REQUIRED")
  end

  it "exposes exit code 7" do
    expect(described_class::AUTH_REQUIRED_EXIT_CODE).to eq(7)
  end

  it "to_response carries error/code/state/suggested_flow/reason" do
    err = described_class.new("login required",
                              state: "github", suggested_flow: "github_login",
                              reason: "redirect_login")
    response = err.to_response
    expect(response[:error]).to eq("login required")
    expect(response[:code]).to eq("AUTH_REQUIRED")
    expect(response[:state]).to eq("github")
    expect(response[:suggested_flow]).to eq("github_login")
    expect(response[:reason]).to eq("redirect_login")
  end

  it "omits nil fields from to_response" do
    response = described_class.new("login").to_response
    expect(response.keys).to contain_exactly(:error, :code)
  end
end

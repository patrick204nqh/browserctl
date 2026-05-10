# frozen_string_literal: true

require "spec_helper"
require "browserctl/server/command_dispatcher"
require "browserctl/server/page_session"
require "browserctl/server/snapshot_builder"

RSpec.describe "structured error payloads on the daemon wire" do
  let(:driver)   { double("driver") }
  let(:pages)    { {} }
  let(:snapshot) { instance_double(Browserctl::SnapshotBuilder) }
  subject(:dispatcher) { Browserctl::CommandDispatcher.new(pages, driver, snapshot) }

  it "fetch returns SCREAMING_SNAKE KEY_NOT_FOUND with context + suggested_action" do
    res = dispatcher.dispatch({ cmd: "fetch", key: "missing" })
    expect(res[:code]).to eq(Browserctl::Error::Codes::KEY_NOT_FOUND)
    expect(res[:context]).to eq(key: "missing")
    expect(res[:suggested_action]).to eq(
      Browserctl::Error::SuggestedActions.for(Browserctl::Error::Codes::KEY_NOT_FOUND)
    )
    expect(res[:error]).to match(/key 'missing' not found/)
  end

  it "navigate returns DOMAIN_NOT_ALLOWED structured payload when policy blocks" do
    allow(Browserctl::Policy).to receive(:allowed_navigation?).and_return(false)
    res = dispatcher.dispatch({ cmd: "navigate", name: "x", url: "http://blocked.example" })
    expect(res[:code]).to eq(Browserctl::Error::Codes::DOMAIN_NOT_ALLOWED)
    expect(res[:context]).to eq(url: "http://blocked.example")
    expect(res[:suggested_action]).to be_a(String)
    expect(res[:suggested_action]).not_to be_empty
  end

  it "click on a missing selector returns SELECTOR_NOT_FOUND with selector context" do
    page = double("page")
    allow(page).to receive(:at_css).and_return(nil)
    pages["home"] = Browserctl::PageSession.new(page)

    res = dispatcher.dispatch({ cmd: "click", name: "home", selector: ".gone" })
    expect(res[:code]).to eq(Browserctl::Error::Codes::SELECTOR_NOT_FOUND)
    expect(res[:context]).to eq(selector: ".gone")
    expect(res[:suggested_action]).to match(/snapshot/i)
  end
end

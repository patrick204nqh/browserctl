# frozen_string_literal: true

require "spec_helper"
require "browserctl/server/command_dispatcher"
require "browserctl/server/snapshot_builder"
require "browserctl/server/page_session"

RSpec.describe "page_focus" do
  let(:pages) { {} }

  def make_dispatcher(headless:)
    opts    = double("options", headless: headless)
    browser = double("browser", options: opts)
    Browserctl::CommandDispatcher.new(pages, browser, Browserctl::SnapshotBuilder.new)
  end

  it "returns error in headless mode" do
    dispatcher = make_dispatcher(headless: true)
    pages["p"] = Browserctl::PageSession.new(double("page"))
    res = dispatcher.dispatch({ cmd: "page_focus", name: "p" })
    expect(res[:error]).to match(/headed mode/)
  end

  it "calls page.activate in headed mode" do
    dispatcher = make_dispatcher(headless: false)
    page       = double("page")
    pages["p"] = Browserctl::PageSession.new(page)
    expect(page).to receive(:activate)
    res = dispatcher.dispatch({ cmd: "page_focus", name: "p" })
    expect(res).to eq({ ok: true })
  end

  it "returns error for missing page" do
    dispatcher = make_dispatcher(headless: false)
    res = dispatcher.dispatch({ cmd: "page_focus", name: "missing" })
    expect(res[:error]).to match(/no page named 'missing'/)
  end
end

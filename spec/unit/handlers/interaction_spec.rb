# frozen_string_literal: true

require "spec_helper"
require "browserctl/server/command_dispatcher"
require "browserctl/server/page_session"
require "support/fake_page_driver"

# Unit-level coverage for the Interaction handler family. Drives every command
# through a {Browserctl::Testing::FakePageDriver} — no Chrome, no Ferrum.
RSpec.describe Browserctl::CommandDispatcher::Handlers::Interaction do
  let(:fake_driver)  { Browserctl::Testing::FakePageDriver.new }
  let(:session)      { Browserctl::PageSession.new(fake_driver) }
  let(:pages)        { { "main" => session } }
  let(:capability_driver) { double("driver") }
  subject(:dispatcher) { Browserctl::CommandDispatcher.new(pages, capability_driver) }

  describe "press" do
    it "calls keyboard_down + keyboard_up via the driver" do
      res = dispatcher.dispatch({ cmd: "press", name: "main", key: "Enter" })
      expect(res).to eq({ ok: true })
      expect(fake_driver.calls_for(:keyboard_down)).to eq([[:keyboard_down, "Enter"]])
      expect(fake_driver.calls_for(:keyboard_up)).to eq([[:keyboard_up, "Enter"]])
    end
  end

  describe "hover" do
    it "evaluates selector geometry then moves the mouse" do
      fake_driver.stub_evaluate_default({ "x" => 10, "y" => 20 })
      res = dispatcher.dispatch({ cmd: "hover", name: "main", selector: "#go" })
      expect(res).to eq({ ok: true })
      expect(fake_driver.calls_for(:mouse_move)).to eq([[:mouse_move, 10, 20]])
    end

    it "returns SELECTOR_NOT_FOUND when geometry probe returns nil" do
      fake_driver.stub_evaluate_default(nil)
      res = dispatcher.dispatch({ cmd: "hover", name: "main", selector: "#ghost" })
      expect(res[:code]).to eq(Browserctl::Error::Codes::SELECTOR_NOT_FOUND)
    end
  end

  describe "select" do
    it "evaluates a value-assignment script on the matched element" do
      el = Browserctl::Testing::FakeElement.new
      fake_driver.register_element("#choice", el)
      res = dispatcher.dispatch({ cmd: "select", name: "main", selector: "#choice", value: "B" })
      expect(res).to eq({ ok: true })
      expect(el.calls.first.first).to eq(:evaluate)
      expect(el.calls.first[1]).to include("dispatchEvent")
    end

    it "returns SELECTOR_NOT_FOUND when at_css returns nil" do
      res = dispatcher.dispatch({ cmd: "select", name: "main", selector: "#ghost", value: "A" })
      expect(res[:code]).to eq(Browserctl::Error::Codes::SELECTOR_NOT_FOUND)
    end
  end

  describe "dialog_accept" do
    it "subscribes to :dialog and unsubscribes inside the callback" do
      dispatcher.dispatch({ cmd: "dialog_accept", name: "main", text: "ok" })
      dialog = double("dialog")
      expect(dialog).to receive(:accept).with("ok")
      fake_driver.emit(:dialog, dialog)
      # Subscription is removed inside the callback
      expect(fake_driver.calls_for(:off)).not_to be_empty
    end
  end
end

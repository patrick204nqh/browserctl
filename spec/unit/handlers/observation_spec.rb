# frozen_string_literal: true

require "spec_helper"
require "browserctl/server/command_dispatcher"
require "browserctl/server/page_session"
require "support/fake_page_driver"

# Unit-level coverage for the Observation handler family. No Chrome, no Ferrum
# — every page interaction routes through {Browserctl::Testing::FakePageDriver}.
RSpec.describe Browserctl::CommandDispatcher::Handlers::Observation do
  let(:fake_driver) { Browserctl::Testing::FakePageDriver.new(body: "<html></html>") }
  let(:session)     { Browserctl::PageSession.new(fake_driver) }
  let(:pages)       { { "main" => session } }
  let(:capability_driver) { double("driver") }
  subject(:dispatcher) { Browserctl::CommandDispatcher.new(pages, capability_driver) }

  describe "snapshot (html format)" do
    it "returns the body and a nonce" do
      res = dispatcher.dispatch({ cmd: "snapshot", name: "main", format: "html" })
      expect(res[:ok]).to be true
      expect(res[:html]).to eq("<html></html>")
      expect(res[:nonce]).to be_a(String)
    end

    it "produces a fresh nonce each call" do
      r1 = dispatcher.dispatch({ cmd: "snapshot", name: "main", format: "html" })
      r2 = dispatcher.dispatch({ cmd: "snapshot", name: "main", format: "html" })
      expect(r1[:nonce]).not_to eq(r2[:nonce])
    end
  end

  describe "auth_check" do
    it "returns auth_required: false when no detector fires" do
      fake_driver.current_url = "https://example.com/dashboard"
      res = dispatcher.dispatch({ cmd: "auth_check", name: "main" })
      expect(res).to eq({ ok: true, auth_required: false })
    end

    it "returns an AUTH_REQUIRED payload when URL matches a login path" do
      fake_driver.current_url = "https://example.com/login"
      res = dispatcher.dispatch({ cmd: "auth_check", name: "main" })
      expect(res[:code]).to eq("AUTH_REQUIRED")
    end
  end

  describe "screenshot" do
    it "passes path: and full: through to the driver" do
      Dir.mktmpdir do |tmp|
        path = File.join(tmp, "shot.png")
        # Allow the screenshot directory pre-check by routing under SCREENSHOT_DIR
        # — bypass safety check by stubbing the path validator via default dir.
        allow_any_instance_of(Browserctl::CommandDispatcher)
          .to receive(:safe_screenshot_path).and_return(path)
        res = dispatcher.dispatch({ cmd: "screenshot", name: "main", path: path })
        expect(res[:ok]).to be true
        expect(fake_driver.calls_for(:screenshot)).to eq([[:screenshot, path, false]])
      end
    end
  end
end

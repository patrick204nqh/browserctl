# frozen_string_literal: true

require "spec_helper"
require "browserctl/server/command_dispatcher"
require "browserctl/server/page_session"
require "support/fake_page_driver"

# Unit-level coverage for the Cookies handler family. No browser; the driver
# is a {Browserctl::Testing::FakePageDriver}.
RSpec.describe Browserctl::CommandDispatcher::Handlers::Cookies do
  let(:fake_driver) { Browserctl::Testing::FakePageDriver.new }
  let(:session)     { Browserctl::PageSession.new(fake_driver) }
  let(:pages)       { { "main" => session } }
  let(:capability_driver) { double("driver") }
  subject(:dispatcher) { Browserctl::CommandDispatcher.new(pages, capability_driver) }

  describe "cookies (list)" do
    it "returns the driver's cookies as an array of hashes" do
      fake_driver.cookies_set(name: "sid", value: "abc", domain: ".example.com", path: "/")
      res = dispatcher.dispatch({ cmd: "cookies", name: "main" })
      expect(res[:ok]).to be true
      expect(res[:cookies].first).to include(name: "sid", value: "abc")
    end

    it "errors for unknown page" do
      res = dispatcher.dispatch({ cmd: "cookies", name: "ghost" })
      expect(res[:error]).to match(/no page named 'ghost'/)
    end
  end

  describe "set_cookie" do
    it "forwards name, value, domain, path to the driver" do
      res = dispatcher.dispatch(
        cmd: "set_cookie", name: "main",
        cookie_name: "sid", value: "abc", domain: ".x.com", path: "/api"
      )
      expect(res).to eq({ ok: true })
      call = fake_driver.calls_for(:cookies_set).first
      expect(call[1]).to include(name: "sid", value: "abc", domain: ".x.com", path: "/api")
    end

    it "defaults path to '/' when omitted" do
      dispatcher.dispatch(
        cmd: "set_cookie", name: "main",
        cookie_name: "sid", value: "abc", domain: ".x.com"
      )
      expect(fake_driver.calls_for(:cookies_set).first[1][:path]).to eq("/")
    end
  end

  describe "delete_cookies" do
    it "calls cookies_clear" do
      fake_driver.cookies_set(name: "sid", value: "abc")
      res = dispatcher.dispatch({ cmd: "delete_cookies", name: "main" })
      expect(res).to eq({ ok: true })
      expect(fake_driver.calls_for(:cookies_clear)).not_to be_empty
      expect(fake_driver.cookies_all).to be_empty
    end
  end

  describe "import_cookies" do
    it "applies each cookie via cookies_set and reports the count" do
      cookies = [
        { name: "a", value: "1", domain: ".x.com" },
        { name: "b", value: "2", domain: ".x.com", path: "/api", secure: true }
      ]
      res = dispatcher.dispatch({ cmd: "import_cookies", name: "main", cookies: cookies })
      expect(res).to eq({ ok: true, count: 2 })
      expect(fake_driver.calls_for(:cookies_set).length).to eq(2)
    end
  end
end

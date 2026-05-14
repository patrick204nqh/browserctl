# frozen_string_literal: true

require "spec_helper"
require "browserctl/server/command_dispatcher"
require "browserctl/server/page_session"
require "support/fake_page_driver"

# Unit-level coverage for the Data handler family (v0.15+, ADR-0021).
# No browser; the driver is a {Browserctl::Testing::FakePageDriver}.
RSpec.describe Browserctl::CommandDispatcher::Handlers::Data do
  let(:fake_driver) { Browserctl::Testing::FakePageDriver.new }
  let(:session)     { Browserctl::PageSession.new(fake_driver) }
  let(:pages)       { { "main" => session } }
  let(:capability_driver) { double("driver") }
  subject(:dispatcher) { Browserctl::CommandDispatcher.new(pages, capability_driver) }

  describe "scope validation" do
    it "rejects an unknown scope with INVALID_ARGUMENT" do
      res = dispatcher.dispatch(cmd: "data_get", name: "main", key: "k", scope: "bogus")
      expect(res[:error]).to match(/invalid --scope/)
      expect(res[:code]).to eq("INVALID_ARGUMENT")
    end

    it "rejects a missing scope with INVALID_ARGUMENT" do
      res = dispatcher.dispatch(cmd: "data_list", name: "main")
      expect(res[:code]).to eq("INVALID_ARGUMENT")
    end

    it "rejects the v0.15 short form 'local' with a hint pointing at 'localStorage'" do
      res = dispatcher.dispatch(cmd: "data_get", name: "main", key: "k", scope: "local")
      expect(res[:code]).to eq("INVALID_ARGUMENT")
      expect(res[:error]).to match(/localStorage/)
    end

    it "rejects the v0.15 short form 'session' with a hint pointing at 'sessionStorage'" do
      res = dispatcher.dispatch(cmd: "data_get", name: "main", key: "k", scope: "session")
      expect(res[:code]).to eq("INVALID_ARGUMENT")
      expect(res[:error]).to match(/sessionStorage/)
    end
  end

  describe "data_set --scope cookies" do
    it "forwards to cookies_set with the documented envelope" do
      res = dispatcher.dispatch(
        cmd: "data_set", name: "main",
        key: "sid", value: "abc", scope: "cookies", domain: ".x.com", path: "/api"
      )
      expect(res).to include(ok: true, scope: "cookies", key: "sid")
      call = fake_driver.calls_for(:cookies_set).first
      expect(call[1]).to include(name: "sid", value: "abc", domain: ".x.com", path: "/api")
    end

    it "errors without --domain" do
      res = dispatcher.dispatch(
        cmd: "data_set", name: "main",
        key: "sid", value: "abc", scope: "cookies"
      )
      expect(res[:code]).to eq("INVALID_ARGUMENT")
    end
  end

  describe "data_list --scope cookies" do
    it "returns the driver's cookies as entries with count" do
      fake_driver.cookies_set(name: "sid", value: "abc", domain: ".example.com", path: "/")
      res = dispatcher.dispatch(cmd: "data_list", name: "main", scope: "cookies")
      expect(res[:ok]).to be true
      expect(res[:scope]).to eq("cookies")
      expect(res[:count]).to eq(1)
      expect(res[:entries].first).to include(name: "sid", value: "abc")
    end
  end

  describe "data_delete --scope cookies" do
    it "calls cookies_clear and reports deleted count" do
      fake_driver.cookies_set(name: "sid", value: "abc")
      res = dispatcher.dispatch(cmd: "data_delete", name: "main", scope: "cookies")
      expect(res).to include(ok: true, scope: "cookies", deleted: 1)
      expect(fake_driver.cookies_all).to be_empty
    end
  end

  describe "data_get --scope localStorage" do
    it "evaluates the localStorage.getItem JS and returns the value" do
      fake_driver.stub_evaluate("localStorage.getItem(\"theme\")", "dark")
      res = dispatcher.dispatch(cmd: "data_get", name: "main", key: "theme", scope: "localStorage")
      expect(res).to include(ok: true, scope: "localStorage", key: "theme", value: "dark")
    end
  end

  describe "data_set --scope sessionStorage" do
    it "evaluates the sessionStorage.setItem JS" do
      res = dispatcher.dispatch(
        cmd: "data_set", name: "main",
        key: "k", value: "v", scope: "sessionStorage"
      )
      expect(res).to include(ok: true, scope: "sessionStorage", key: "k")
      call = fake_driver.calls_for(:evaluate).last
      expect(call[1]).to eq("sessionStorage.setItem(\"k\", \"v\")")
    end
  end

  describe "data_get --scope cookies" do
    it "is rejected (use data_list)" do
      res = dispatcher.dispatch(cmd: "data_get", name: "main", key: "x", scope: "cookies")
      expect(res[:code]).to eq("INVALID_ARGUMENT")
    end
  end
end

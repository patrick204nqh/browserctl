# frozen_string_literal: true

require "spec_helper"
require "browserctl/server/command_dispatcher"
require "browserctl/server/snapshot_builder"

RSpec.describe Browserctl::CommandDispatcher do
  let(:browser)    { double("browser") }
  let(:pages)      { {} }
  let(:snapshot)   { instance_double(Browserctl::SnapshotBuilder) }
  subject(:dispatcher) { described_class.new(pages, browser, snapshot) }

  describe "#dispatch" do
    it "returns error for unknown command" do
      expect(dispatcher.dispatch({ cmd: "nope" })).to eq({ error: "unknown command: nope" })
    end

    it "responds to ping with pid" do
      result = dispatcher.dispatch({ cmd: "ping" })
      expect(result[:ok]).to be true
      expect(result[:pid]).to eq(Process.pid)
    end

    it "responds to list_pages" do
      pages["main"] = double("page")
      expect(dispatcher.dispatch({ cmd: "list_pages" })).to eq({ pages: ["main"] })
    end

    it "returns error for missing page" do
      result = dispatcher.dispatch({ cmd: "goto", name: "missing", url: "http://x.com" })
      expect(result[:error]).to match(/no page named 'missing'/)
    end

    it "open_page creates and stores a page" do
      page = double("page")
      allow(browser).to receive(:create_page).and_return(page)
      result = dispatcher.dispatch({ cmd: "open_page", name: "home" })
      expect(result).to eq({ ok: true, name: "home" })
      expect(pages["home"]).to eq(page)
    end

    it "open_page navigates to url when given" do
      page = double("page")
      allow(browser).to receive(:create_page).and_return(page)
      expect(page).to receive(:go_to).with("http://example.com")
      dispatcher.dispatch({ cmd: "open_page", name: "home", url: "http://example.com" })
    end

    it "open_page re-navigates an existing page when url is given" do
      page = double("page")
      pages["home"] = page
      expect(page).to receive(:go_to).with("http://example.com/new")
      result = dispatcher.dispatch({ cmd: "open_page", name: "home", url: "http://example.com/new" })
      expect(result).to eq({ ok: true, name: "home" })
    end

    it "close_page removes page and closes it" do
      page = double("page")
      allow(page).to receive(:close)
      pages["home"] = page
      result = dispatcher.dispatch({ cmd: "close_page", name: "home" })
      expect(result).to eq({ ok: true })
      expect(pages.key?("home")).to be false
    end

    it "shutdown sends SIGINT to current process" do
      expect(Process).to receive(:kill).with("INT", Process.pid)
      result = dispatcher.dispatch({ cmd: "shutdown" })
      expect(result).to eq({ ok: true })
    end
  end

  describe "#cmd_snapshot (state storage)" do
    let(:page)    { instance_double("Ferrum::Page", body: "<html><body><button>Go</button></body></html>") }
    let(:pages)   { { "main" => page } }
    let(:builder) { Browserctl::SnapshotBuilder.new }
    subject(:dispatcher) { described_class.new(pages, double("browser"), builder) }

    it "stores ref registry after ai snapshot" do
      dispatcher.dispatch({ cmd: "snapshot", name: "main", format: "ai" })
      reg = dispatcher.instance_variable_get(:@ref_registries)
      expect(reg["main"]).to be_a(Hash)
      expect(reg["main"].keys).to all(match(/\Ae\d+\z/))
    end

    it "stores previous snapshot after ai snapshot" do
      dispatcher.dispatch({ cmd: "snapshot", name: "main", format: "ai" })
      prev = dispatcher.instance_variable_get(:@prev_snapshots)
      expect(prev["main"]).to be_an(Array)
    end

    it "does not store state for html format" do
      allow(page).to receive(:body).and_return("<html></html>")
      dispatcher.dispatch({ cmd: "snapshot", name: "main", format: "html" })
      expect(dispatcher.instance_variable_get(:@ref_registries)["main"]).to be_nil
    end
  end
end

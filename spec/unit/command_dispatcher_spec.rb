# frozen_string_literal: true

require "spec_helper"
require "browserctl/server/command_dispatcher"
require "browserctl/server/snapshot_builder"
require "browserctl/server/page_session"

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
      pages["main"] = Browserctl::PageSession.new(double("page"))
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
      expect(pages["home"]).to be_a(Browserctl::PageSession)
      expect(pages["home"].page).to eq(page)
    end

    it "open_page navigates to url when given" do
      page = double("page")
      allow(browser).to receive(:create_page).and_return(page)
      expect(page).to receive(:go_to).with("http://example.com")
      dispatcher.dispatch({ cmd: "open_page", name: "home", url: "http://example.com" })
    end

    it "open_page re-navigates an existing page when url is given" do
      page = double("page")
      pages["home"] = Browserctl::PageSession.new(page)
      expect(page).to receive(:go_to).with("http://example.com/new")
      result = dispatcher.dispatch({ cmd: "open_page", name: "home", url: "http://example.com/new" })
      expect(result).to eq({ ok: true, name: "home" })
    end

    it "close_page removes page and closes it" do
      page = double("page")
      allow(page).to receive(:close)
      pages["home"] = Browserctl::PageSession.new(page)
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

  describe "ref-based interaction" do
    let(:html) { '<html><body><input name="email"><button>Go</button></body></html>' }
    let(:page) { instance_double("Ferrum::Page", body: html) }
    let(:pages) { { "main" => Browserctl::PageSession.new(page) } }
    subject(:dispatcher) { described_class.new(pages, double("browser")) }

    before do
      dispatcher.dispatch({ cmd: "snapshot", name: "main", format: "ai" })
    end

    it "resolves ref to selector for click" do
      allow(page).to receive(:at_css).and_return(double("el", click: nil))
      res = dispatcher.dispatch({ cmd: "click", name: "main", ref: "e2" })
      expect(res[:ok]).to be true
    end

    it "returns error for unknown ref" do
      res = dispatcher.dispatch({ cmd: "click", name: "main", ref: "e99" })
      expect(res[:error]).to match(/ref 'e99' not found/)
    end

    it "resolves ref to selector for fill" do
      el = double("el", focus: nil, type: nil)
      allow(page).to receive(:at_css).and_return(el)
      res = dispatcher.dispatch({ cmd: "fill", name: "main", ref: "e1", value: "test@example.com" })
      expect(res[:ok]).to be true
    end

    it "returns error if neither selector nor ref is given for click" do
      res = dispatcher.dispatch({ cmd: "click", name: "main" })
      expect(res[:error]).to match(/selector or ref required/)
    end
  end

  describe "snap --diff" do
    let(:html_v1) { '<html><body><button id="a">A</button></body></html>' }
    let(:html_v2) { '<html><body><button id="a">A</button><button id="b">B</button></body></html>' }
    let(:page)    { instance_double("Ferrum::Page") }
    let(:pages)   { { "main" => Browserctl::PageSession.new(page) } }
    subject(:dispatcher) { described_class.new(pages, double("browser")) }

    it "returns full snapshot on first call with diff: true (no previous)" do
      allow(page).to receive(:body).and_return(html_v1)
      res = dispatcher.dispatch({ cmd: "snapshot", name: "main", format: "ai", diff: true })
      expect(res[:snapshot].length).to eq 1
    end

    it "returns only new/changed elements on subsequent diff call" do
      allow(page).to receive(:body).and_return(html_v1)
      dispatcher.dispatch({ cmd: "snapshot", name: "main", format: "ai" })

      allow(page).to receive(:body).and_return(html_v2)
      res = dispatcher.dispatch({ cmd: "snapshot", name: "main", format: "ai", diff: true })
      expect(res[:snapshot].length).to eq 1
      expect(res[:snapshot].first[:selector]).to include("#b")
    end

    it "returns empty array when nothing changed" do
      allow(page).to receive(:body).and_return(html_v1)
      dispatcher.dispatch({ cmd: "snapshot", name: "main", format: "ai" })
      res = dispatcher.dispatch({ cmd: "snapshot", name: "main", format: "ai", diff: true })
      expect(res[:snapshot]).to be_empty
    end
  end

  describe "#cmd_screenshot" do
    let(:page)  { instance_double("Ferrum::Page") }
    let(:pages) { { "main" => Browserctl::PageSession.new(page) } }
    subject(:dispatcher) { described_class.new(pages, double("browser")) }

    it "rejects paths outside the allowed screenshot directory" do
      res = dispatcher.dispatch({ cmd: "screenshot", name: "main",
                                  path: "/tmp/../Users/nqhuy25/.ssh/authorized_keys" })
      expect(res[:error]).to match(/outside allowed directory/)
    end

    it "rejects paths without .png or .jpg extension" do
      res = dispatcher.dispatch({ cmd: "screenshot", name: "main",
                                  path: File.expand_path("~/.browserctl/screenshots/evil.rb") })
      expect(res[:error]).to match(/invalid extension/)
    end

    it "accepts a valid path inside the allowed directory" do
      allowed = File.expand_path("~/.browserctl/screenshots/test.png")
      FileUtils.mkdir_p(File.dirname(allowed))
      allow(page).to receive(:screenshot)
      res = dispatcher.dispatch({ cmd: "screenshot", name: "main", path: allowed })
      expect(res[:ok]).to be true
      expect(res[:path]).to eq(allowed)
    end
  end

  describe "#cmd_watch" do
    let(:page)  { instance_double("Ferrum::Page") }
    let(:pages) { { "main" => Browserctl::PageSession.new(page) } }
    subject(:dispatcher) { described_class.new(pages, double("browser")) }

    it "returns ok with selector when element appears" do
      call_count = 0
      allow(page).to receive(:at_css) do |_sel|
        call_count += 1
        call_count >= 2 ? double("el") : nil
      end
      res = dispatcher.dispatch({ cmd: "watch", name: "main", selector: ".result", timeout: 1 })
      expect(res[:ok]).to be true
      expect(res[:selector]).to eq ".result"
    end

    it "returns error on timeout" do
      allow(page).to receive(:at_css).and_return(nil)
      res = dispatcher.dispatch({ cmd: "watch", name: "main", selector: ".missing", timeout: 0.2 })
      expect(res[:error]).to match(/timeout/)
    end
  end

  describe "#cmd_snapshot (state storage)" do
    let(:page)    { instance_double("Ferrum::Page", body: "<html><body><button>Go</button></body></html>") }
    let(:pages)   { { "main" => Browserctl::PageSession.new(page) } }
    let(:builder) { Browserctl::SnapshotBuilder.new }
    subject(:dispatcher) { described_class.new(pages, double("browser"), builder) }

    it "stores ref registry after ai snapshot" do
      dispatcher.dispatch({ cmd: "snapshot", name: "main", format: "ai" })
      expect(pages["main"].ref_registry).to be_a(Hash)
      expect(pages["main"].ref_registry).not_to be_empty
    end

    it "stores previous snapshot after ai snapshot" do
      dispatcher.dispatch({ cmd: "snapshot", name: "main", format: "ai" })
      expect(pages["main"].prev_snapshot).to be_an(Array)
    end

    it "does not store state for html format" do
      allow(page).to receive(:body).and_return("<html></html>")
      dispatcher.dispatch({ cmd: "snapshot", name: "main", format: "html" })
      expect(pages["main"].ref_registry).to be_empty
    end

    it "evicts ref_registry and prev_snapshot when page is closed" do
      page2 = instance_double("Ferrum::Page", body: "<html><body><button>Go</button></body></html>")
      allow(page2).to receive(:close)
      pages["temp"] = Browserctl::PageSession.new(page2)
      dispatcher.dispatch({ cmd: "snapshot", name: "temp", format: "ai" })
      expect(pages["temp"].ref_registry).not_to be_empty

      dispatcher.dispatch({ cmd: "close_page", name: "temp" })
      expect(pages.key?("temp")).to be false
    end
  end
end

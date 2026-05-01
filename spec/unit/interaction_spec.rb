# frozen_string_literal: true

require "spec_helper"
require "browserctl/server/command_dispatcher"
require "browserctl/server/snapshot_builder"
require "browserctl/server/page_session"

RSpec.describe "interaction handlers" do
  let(:browser)    { double("browser") }
  let(:pages)      { {} }
  subject(:dispatcher) { Browserctl::CommandDispatcher.new(pages, browser, Browserctl::SnapshotBuilder.new) }

  def make_page(page_double)
    pages["p"] = Browserctl::PageSession.new(page_double)
  end

  describe "press" do
    it "fires keydown and keyup via keyboard" do
      keyboard = double("keyboard")
      page     = double("page", keyboard: keyboard)
      make_page(page)
      expect(keyboard).to receive(:down).with("Enter")
      expect(keyboard).to receive(:up).with("Enter")
      res = dispatcher.dispatch({ cmd: "press", name: "p", key: "Enter" })
      expect(res).to eq({ ok: true })
    end

    it "returns error for missing page" do
      res = dispatcher.dispatch({ cmd: "press", name: "missing", key: "Enter" })
      expect(res[:error]).to match(/no page named 'missing'/)
    end
  end

  describe "hover" do
    it "moves mouse to element center" do
      mouse = double("mouse")
      page  = double("page", mouse: mouse)
      make_page(page)
      allow(page).to receive(:evaluate)
        .with(a_string_including("getBoundingClientRect"))
        .and_return({ "x" => 50.0, "y" => 80.0 })
      expect(mouse).to receive(:move).with(x: 50.0, y: 80.0)
      res = dispatcher.dispatch({ cmd: "hover", name: "p", selector: "#btn" })
      expect(res).to eq({ ok: true })
    end

    it "returns error when selector not found" do
      page = double("page")
      make_page(page)
      allow(page).to receive(:evaluate)
        .with(a_string_including("getBoundingClientRect"))
        .and_return(nil)
      res = dispatcher.dispatch({ cmd: "hover", name: "p", selector: "#missing" })
      expect(res[:error]).to match(/selector not found/)
    end
  end

  describe "upload" do
    it "calls select_file on the element" do
      el   = double("node")
      page = double("page")
      make_page(page)
      allow(page).to receive(:at_css).with("#file").and_return(el)
      expect(el).to receive(:select_file).with("/tmp/test.txt")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with("/tmp/test.txt").and_return(true)
      res = dispatcher.dispatch({ cmd: "upload", name: "p", selector: "#file", path: "/tmp/test.txt" })
      expect(res).to eq({ ok: true })
    end

    it "returns error when file not found" do
      page = double("page")
      make_page(page)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with("/nonexistent.txt").and_return(false)
      res = dispatcher.dispatch({ cmd: "upload", name: "p", selector: "#file", path: "/nonexistent.txt" })
      expect(res[:error]).to match(/file not found/)
    end

    it "returns error when selector not found" do
      page = double("page")
      make_page(page)
      allow(page).to receive(:at_css).with("#nope").and_return(nil)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with("/tmp/f.txt").and_return(true)
      res = dispatcher.dispatch({ cmd: "upload", name: "p", selector: "#nope", path: "/tmp/f.txt" })
      expect(res[:error]).to match(/selector not found/)
    end
  end

  describe "select" do
    it "sets value and fires change event" do
      el   = double("node")
      page = double("page")
      make_page(page)
      allow(page).to receive(:at_css).with("select#lang").and_return(el)
      expect(el).to receive(:evaluate)
        .with("this.value = \"ruby\"; this.dispatchEvent(new Event('change', {bubbles: true}))")
      res = dispatcher.dispatch({ cmd: "select", name: "p", selector: "select#lang", value: "ruby" })
      expect(res).to eq({ ok: true })
    end

    it "returns error when selector not found" do
      page = double("page")
      make_page(page)
      allow(page).to receive(:at_css).with("select#nope").and_return(nil)
      res = dispatcher.dispatch({ cmd: "select", name: "p", selector: "select#nope", value: "x" })
      expect(res[:error]).to match(/selector not found/)
    end
  end

  describe "hover with ref" do
    it "resolves selector from ref_registry and moves mouse" do
      mouse = double("mouse")
      page  = double("page", mouse: mouse)
      make_page(page)
      pages["p"].ref_registry = { "e4" => "#dropdown" }
      allow(page).to receive(:evaluate)
        .with(a_string_including("getBoundingClientRect"))
        .and_return({ "x" => 100.0, "y" => 200.0 })
      expect(mouse).to receive(:move).with(x: 100.0, y: 200.0)
      res = dispatcher.dispatch({ cmd: "hover", name: "p", ref: "e4" })
      expect(res).to eq({ ok: true })
    end

    it "returns error for unknown ref" do
      page = double("page")
      make_page(page)
      pages["p"].ref_registry = {}
      res = dispatcher.dispatch({ cmd: "hover", name: "p", ref: "e99" })
      expect(res[:error]).to match(/ref 'e99' not found/)
    end
  end

  describe "upload with ref" do
    it "resolves selector from ref_registry" do
      page = double("page")
      make_page(page)
      pages["p"].ref_registry = { "e5" => "#file-input" }
      el = double("el")
      allow(page).to receive(:at_css).with("#file-input").and_return(el)
      expect(el).to receive(:select_file).with(anything)
      # Use a real file path — use __FILE__ (this spec file itself)
      res = dispatcher.dispatch({ cmd: "upload", name: "p", ref: "e5", path: __FILE__ })
      expect(res).to eq({ ok: true })
    end
  end

  describe "select with ref" do
    it "resolves selector from ref_registry" do
      page = double("page")
      make_page(page)
      pages["p"].ref_registry = { "e6" => "#country" }
      el = double("el")
      allow(page).to receive(:at_css).with("#country").and_return(el)
      allow(el).to receive(:evaluate)
      res = dispatcher.dispatch({ cmd: "select", name: "p", ref: "e6", value: "AU" })
      expect(res).to eq({ ok: true })
    end
  end
end

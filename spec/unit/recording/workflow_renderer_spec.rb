# frozen_string_literal: true

require "browserctl"

RSpec.describe Browserctl::Recording::WorkflowRenderer do
  describe ".render" do
    it "produces a workflow with a format_version comment header" do
      ruby = described_class.render("noop", [])
      expect(ruby).to include("# format_version: #{Browserctl::WORKFLOW_FORMAT_VERSION}")
      expect(ruby).to include('Browserctl.workflow "noop" do')
    end

    it "renders a navigate command into a page().navigate step" do
      ruby = described_class.render("ex", [{ cmd: "navigate", name: "home", url: "https://example.com" }])
      expect(ruby).to include('step "navigate home" do')
      expect(ruby).to include('page(:home).navigate("https://example.com")')
    end

    it "wires fill values to params[:fill_value] by default" do
      ruby = described_class.render("ex", [{ cmd: "fill", name: "login", selector: "input" }])
      expect(ruby).to include('page(:login).fill("input", params[:fill_value])')
    end

    it "wires secret-shaped fills to params[:secret_<field>]" do
      cmds = [{ cmd: "fill", name: "login", selector: "input[name=password]", secret_field: "password" }]
      ruby = described_class.render("ex", cmds)
      expect(ruby).to include("param :secret_password, secret: true")
      expect(ruby).to include("page(:login).fill(\"input[name=password]\", params[:secret_password])")
    end

    it "emits a TODO when a ref-interaction is present (no replayable selector)" do
      cmds = [{ cmd: "_ref_interaction", name: "p", action: "click", ref: "abc123" }]
      ruby = described_class.render("ex", cmds)
      expect(ruby).to include("TODO: ref-based click")
    end
  end

  describe ".canonical_url" do
    it "strips query and fragment, keeping scheme/host/path" do
      expect(described_class.canonical_url("https://e.com/p?x=1#y")).to eq("https://e.com/p")
    end

    it "normalises an empty path to /" do
      expect(described_class.canonical_url("https://e.com")).to eq("https://e.com/")
    end

    it "returns nil for blank input" do
      expect(described_class.canonical_url(nil)).to be_nil
      expect(described_class.canonical_url("")).to be_nil
    end

    it "returns nil for unparseable URLs" do
      expect(described_class.canonical_url("http://exa mple.com")).to be_nil
    end
  end

  describe ".inferred_wait_step" do
    it "emits a wait when the gap exceeds the threshold for a selector step" do
      prev = { cmd: "navigate", ts: 0.0 }
      cur  = { cmd: "click", name: "p", selector: "a.next", ts: 3.0 }
      out  = described_class.inferred_wait_step(prev, cur)
      expect(out).to include('page(:p).wait("a.next"')
    end

    it "returns nil for sub-threshold gaps" do
      prev = { cmd: "navigate", ts: 0.0 }
      cur  = { cmd: "click", name: "p", selector: "a", ts: 0.5 }
      expect(described_class.inferred_wait_step(prev, cur)).to be_nil
    end

    it "returns nil when timestamps are missing" do
      prev = { cmd: "navigate" }
      cur  = { cmd: "click", name: "p", selector: "a" }
      expect(described_class.inferred_wait_step(prev, cur)).to be_nil
    end
  end
end

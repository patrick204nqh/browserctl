# frozen_string_literal: true

require "spec_helper"
require "nokogiri"
require "browserctl/snapshot/fingerprint"

RSpec.describe Browserctl::Snapshot::Fingerprint do
  subject(:fingerprint) { described_class.new }

  def node(html, css)
    Nokogiri::HTML(html).at_css(css)
  end

  describe "#build" do
    it "captures text, role, neighbors, and position" do
      html = <<~HTML
        <html><body><form>
          <label>Email</label>
          <input type="email" placeholder="you@example.com">
          <button>Submit</button>
        </form></body></html>
      HTML
      fp = fingerprint.build(node(html, "input"))

      expect(fp[:text]).to eq("you@example.com")
      expect(fp[:role]).to eq("textbox")
      expect(fp[:neighbors]).to include(match(/label:Email/), match(/button:Submit/))
      expect(fp[:position]).to include(:index, :depth)
      expect(fp[:position][:depth]).to be > 0
    end

    it "uses explicit role over implicit tag role" do
      html = "<html><body><a role='button'>Go</a></body></html>"
      expect(fingerprint.build(node(html, "a"))[:role]).to eq("button")
    end

    it "is stable when an unrelated class is added" do
      base    = node("<html><body><div><button>Save</button><span>x</span></div></body></html>", "button")
      mutated = node("<html><body><div><button class='primary-x9'>Save</button><span>x</span></div></body></html>",
                     "button")
      expect(fingerprint.build(base)).to eq(fingerprint.build(mutated))
    end

    it "differs when accessible name changes" do
      a = node("<html><body><button>Save</button></body></html>", "button")
      b = node("<html><body><button>Cancel</button></body></html>", "button")
      expect(fingerprint.build(a)[:text]).not_to eq(fingerprint.build(b)[:text])
    end

    it "returns empty neighbors when element has no siblings" do
      html = "<html><body><button>Solo</button></body></html>"
      expect(fingerprint.build(node(html, "button"))[:neighbors]).to eq([])
    end
  end
end

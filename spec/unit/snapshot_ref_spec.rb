# frozen_string_literal: true

require "spec_helper"
require "nokogiri"
require "browserctl/snapshot/ref"

RSpec.describe Browserctl::Snapshot::RefDeriver do
  subject(:deriver) { described_class.new }

  def first_node(html, css)
    Nokogiri::HTML(html).at_css(css)
  end

  describe "#derive" do
    it "produces e<7-hex>" do
      node = first_node("<html><body><button>Go</button></body></html>", "button")
      expect(deriver.derive(node)).to match(/\Ae[0-9a-f]{7}\z/)
    end

    it "is deterministic for the same node signal" do
      html = "<html><body><a href='/x'>Hi</a></body></html>"
      a = deriver.derive(first_node(html, "a"))
      b = deriver.derive(first_node(html, "a"))
      expect(a).to eq(b)
    end

    it "is unaffected by class-only mutations" do
      base    = first_node("<html><body><a>Hi</a></body></html>", "a")
      mutated = first_node("<html><body><a class='renamed-x'>Hi</a></body></html>", "a")
      expect(deriver.derive(base)).to eq(deriver.derive(mutated))
    end

    it "differs when accessible name changes" do
      a = first_node("<html><body><button>Save</button></body></html>", "button")
      b = first_node("<html><body><button>Cancel</button></body></html>", "button")
      expect(deriver.derive(a)).not_to eq(deriver.derive(b))
    end

    it "differs when parent path changes" do
      a = first_node("<html><body><div><a>X</a></div></body></html>", "a")
      b = first_node("<html><body><form><a>X</a></form></body></html>", "a")
      expect(deriver.derive(a)).not_to eq(deriver.derive(b))
    end

    it "prefers explicit role over implicit tag role" do
      a = first_node("<html><body><a role='button'>Go</a></body></html>", "a")
      b = first_node("<html><body><a>Go</a></body></html>", "a")
      expect(deriver.derive(a)).not_to eq(deriver.derive(b))
    end
  end

  describe "#disambiguate" do
    it "returns ref unchanged when not taken" do
      expect(deriver.disambiguate("eabc1234", {})).to eq("eabc1234")
    end

    it "appends -2 on first collision, -3 on next, etc" do
      taken = { "eabc1234" => true }
      expect(deriver.disambiguate("eabc1234", taken)).to eq("eabc1234-2")
      taken["eabc1234-2"] = true
      expect(deriver.disambiguate("eabc1234", taken)).to eq("eabc1234-3")
    end
  end
end

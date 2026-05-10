# frozen_string_literal: true

require "spec_helper"
require "nokogiri"
require "browserctl/snapshot/ref"

# Gap-coverage specs for the ref hashing algorithm. The existing
# `spec/unit/snapshot_ref_spec.rb` covers basic determinism and a few
# signal-sensitivity cases. These add: format invariants, cross-process
# stability proxy, non-ASCII / very long inputs, and disambiguation
# pathologies.
RSpec.describe Browserctl::Snapshot::RefDeriver do
  subject(:deriver) { described_class.new }

  def first_node(html, css)
    Nokogiri::HTML(html).at_css(css)
  end

  describe "ref format invariants" do
    it "always starts with 'e' and has exactly HASH_LEN hex chars after" do
      node = first_node("<html><body><button>Go</button></body></html>", "button")
      ref = deriver.derive(node)
      expect(ref).to match(/\Ae[0-9a-f]{#{described_class::HASH_LEN}}\z/)
    end

    it "produces a fixed total length of HASH_LEN + 1" do
      nodes = [
        first_node("<html><body><button>A</button></body></html>", "button"),
        first_node("<html><body><a>Bxxxxxxxxxxxxxxxxxxxxxx</a></body></html>", "a"),
        first_node("<html><body><input placeholder='you@example.com'></body></html>", "input")
      ]
      nodes.each do |n|
        expect(deriver.derive(n).length).to eq(described_class::HASH_LEN + 1)
      end
    end

    it "uses lowercase hex only (no uppercase, no non-hex)" do
      20.times do |i|
        node = first_node("<html><body><button>Btn#{i}</button></body></html>", "button")
        suffix = deriver.derive(node)[1..]
        expect(suffix).to match(/\A[0-9a-f]+\z/)
      end
    end
  end

  describe "stability across signal-irrelevant noise" do
    it "is unaffected by leading/trailing whitespace in accessible name" do
      a = first_node("<html><body><button>  Save  </button></body></html>", "button")
      b = first_node("<html><body><button>Save</button></body></html>", "button")
      expect(deriver.derive(a)).to eq(deriver.derive(b))
    end

    it "is a pure function of node signal (no hidden process state)" do
      # Proxy for cross-process stability: derive once, GC-churn, derive again.
      node = first_node("<html><body><a href='/x'>Hello</a></body></html>", "a")
      first = deriver.derive(node)
      GC.start
      second = described_class.new.derive(node)
      expect(second).to eq(first)
    end
  end

  describe "edge case inputs" do
    it "handles empty accessible name without raising" do
      node = first_node("<html><body><div></div></body></html>", "div")
      expect { deriver.derive(node) }.not_to raise_error
      expect(deriver.derive(node)).to match(/\Ae[0-9a-f]{7}\z/)
    end

    it "handles non-ASCII text" do
      a = first_node("<html><body><button>你好</button></body></html>", "button")
      b = first_node("<html><body><button>Hello</button></body></html>", "button")
      expect(deriver.derive(a)).not_to eq(deriver.derive(b))
      expect(deriver.derive(a)).to match(/\Ae[0-9a-f]{7}\z/)
    end

    it "handles very long accessible name (truncates internally)" do
      long_text = "x" * 5000
      node = first_node("<html><body><button>#{long_text}</button></body></html>", "button")
      expect { deriver.derive(node) }.not_to raise_error
      expect(deriver.derive(node)).to match(/\Ae[0-9a-f]{7}\z/)
    end
  end

  describe "#disambiguate edge cases" do
    it "returns ref unchanged when taken is empty" do
      expect(deriver.disambiguate("eabc1234", {})).to eq("eabc1234")
    end

    it "skips over a sparse taken set and finds the next free slot" do
      taken = { "eabc1234" => true, "eabc1234-2" => true, "eabc1234-3" => true }
      expect(deriver.disambiguate("eabc1234", taken)).to eq("eabc1234-4")
    end

    it "is idempotent for a ref already disambiguated and not in taken" do
      expect(deriver.disambiguate("eabc1234-2", {})).to eq("eabc1234-2")
    end
  end
end

# frozen_string_literal: true

require "spec_helper"
require "browserctl/server/snapshot_builder"

RSpec.describe Browserctl::SnapshotBuilder do
  subject(:builder) { described_class.new }

  def page_with(html) = double("page", body: html)

  describe "#call" do
    it "returns an array of element entries with required keys" do
      result = builder.call(page_with("<html><body><a href='/'>Home</a></body></html>"))
      expect(result).to be_an(Array)
      expect(result.first).to include(:ref, :tag, :text, :selector, :attrs, :fingerprint)
    end

    it "emits a fingerprint hash per element" do
      result = builder.call(page_with("<html><body><button>Go</button></body></html>"))
      expect(result.first[:fingerprint]).to include(:text, :role, :neighbors, :position)
    end

    it "derives stable hash-prefixed refs (e<7-hex>)" do
      html = "<html><body><a>One</a><button>Two</button></body></html>"
      refs = builder.call(page_with(html)).map { |e| e[:ref] }
      expect(refs).to all(match(/\Ae[0-9a-f]{7}(-\d+)?\z/))
      expect(refs.uniq.size).to eq(refs.size)
    end

    it "produces identical refs across two snapshots of the same page" do
      html = "<html><body><a>One</a><button>Two</button></body></html>"
      first  = builder.call(page_with(html)).map { |e| e[:ref] }
      second = builder.call(page_with(html)).map { |e| e[:ref] }
      expect(first).to eq(second)
    end

    it "disambiguates collisions with a numeric suffix" do
      # Two anchors with identical role/name/tag/parent-path should collide
      # on the base hash and get -2 appended to the second.
      html = "<html><body><a>Same</a><a>Same</a></body></html>"
      refs = builder.call(page_with(html)).map { |e| e[:ref] }
      expect(refs.size).to eq(2)
      expect(refs[0]).to match(/\Ae[0-9a-f]{7}\z/)
      expect(refs[1]).to eq("#{refs[0]}-2")
    end
  end
end

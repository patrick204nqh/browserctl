# frozen_string_literal: true

require "spec_helper"
require "browserctl/server/snapshot_builder"

RSpec.describe Browserctl::SnapshotBuilder do
  subject(:builder) { described_class.new }

  describe "#call" do
    it "returns an array of element entries with required keys" do
      page = double("page", body: "<html><body><a href='/'>Home</a></body></html>")
      result = builder.call(page)
      expect(result).to be_an(Array)
      expect(result.first).to include(:ref, :tag, :text, :selector, :attrs)
    end

    it "increments ref counters per element" do
      html = "<html><body><a>One</a><button>Two</button></body></html>"
      page = double("page", body: html)
      refs = builder.call(page).map { |e| e[:ref] }
      expect(refs).to eq(%w[e1 e2])
    end
  end
end

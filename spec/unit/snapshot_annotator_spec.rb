# frozen_string_literal: true

require "spec_helper"
require "nokogiri"
require "browserctl/snapshot/annotator"

RSpec.describe Browserctl::Snapshot::Annotator do
  subject(:annotator) { described_class.new }

  def nodes_for(html, css)
    Nokogiri::HTML(html).css(css).to_a
  end

  it "produces entries with ref, tag, text, selector, attrs, fingerprint" do
    html = "<html><body><a href='/'>Home</a></body></html>"
    entries = annotator.call(nodes_for(html, "a"))
    expect(entries.first.keys).to include(:ref, :tag, :text, :selector, :attrs, :fingerprint)
    expect(entries.first[:tag]).to eq("a")
    expect(entries.first[:attrs]).to include("href" => "/")
  end

  it "deduplicates colliding refs with -2 suffix" do
    nodes = nodes_for("<html><body><a>Same</a><a>Same</a></body></html>", "a")
    refs = annotator.call(nodes).map { |e| e[:ref] }
    expect(refs.size).to eq(2)
    expect(refs[1]).to eq("#{refs[0]}-2")
  end

  it "is decoupled from extraction (works on raw nodes)" do
    nodes = nodes_for("<html><body><button id='go'>Go</button></body></html>", "button")
    entries = annotator.call(nodes)
    expect(entries.first[:selector]).to include("button#go")
  end
end

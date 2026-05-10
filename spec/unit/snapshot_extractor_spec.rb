# frozen_string_literal: true

require "spec_helper"
require "browserctl/snapshot/extractor"

RSpec.describe Browserctl::Snapshot::Extractor do
  subject(:extractor) { described_class.new }

  it "returns interactable nodes from HTML" do
    html = <<~HTML
      <html><body>
        <p>Not interactable</p>
        <a>Link</a>
        <button>Btn</button>
        <input type="text">
        <div role="button">Custom</div>
      </body></html>
    HTML
    nodes = extractor.call(html)
    expect(nodes.map(&:name)).to contain_exactly("a", "button", "input", "div")
  end

  it "returns an empty array when no interactable elements are present" do
    expect(extractor.call("<html><body><p>plain</p></body></html>")).to eq([])
  end
end

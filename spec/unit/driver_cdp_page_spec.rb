# frozen_string_literal: true

require "spec_helper"
require "browserctl/driver/cdp_page"

RSpec.describe Browserctl::Driver::CDPPage do
  let(:underlying) { double("ferrum_page", current_url: "https://example.com", title: "Example", target_id: "ABC123") }
  subject(:cdp_page) { described_class.new(underlying) }

  it "delegates #current_url to underlying page" do
    expect(cdp_page.current_url).to eq("https://example.com")
  end

  it "delegates #title to underlying page" do
    expect(cdp_page.title).to eq("Example")
  end

  it "delegates #target_id to underlying page" do
    expect(cdp_page.target_id).to eq("ABC123")
  end

  it "wraps the underlying object via SimpleDelegator" do
    expect(cdp_page.__getobj__).to eq(underlying)
  end
end

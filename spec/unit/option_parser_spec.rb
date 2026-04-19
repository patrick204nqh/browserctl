# frozen_string_literal: true

require "spec_helper"
require "browserctl/commands/option_parser"

RSpec.describe Browserctl::Commands::OptionParser do
  describe ".extract_opt" do
    it "extracts a flag and its value, mutating args" do
      args = ["page", "--url", "http://x.com"]
      val  = described_class.extract_opt(args, "--url")
      expect(val).to eq("http://x.com")
      expect(args).to eq(["page"])
    end

    it "returns nil when flag is absent and leaves args unchanged" do
      args = ["page"]
      expect(described_class.extract_opt(args, "--url")).to be_nil
      expect(args).to eq(["page"])
    end
  end
end

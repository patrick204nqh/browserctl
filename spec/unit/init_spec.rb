# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "browserctl/commands/init"

RSpec.describe Browserctl::Commands::Init do
  around do |ex|
    Dir.mktmpdir { |d| Dir.chdir(d) { ex.run } }
  end

  describe ".run" do
    it "creates .browserctl/workflows directory" do
      described_class.run([])
      expect(Dir.exist?(".browserctl/workflows")).to be true
    end

    it "creates .browserctl/config.yml" do
      described_class.run([])
      expect(File.exist?(".browserctl/config.yml")).to be true
    end

    it "config.yml contains daemon key as a comment" do
      described_class.run([])
      content = File.read(".browserctl/config.yml")
      expect(content).to include("daemon")
    end

    it "creates .browserctl/workflows/.keep" do
      described_class.run([])
      expect(File.exist?(".browserctl/workflows/.keep")).to be true
    end

    it "is idempotent — running twice does not raise" do
      described_class.run([])
      expect { described_class.run([]) }.not_to raise_error
    end
  end
end

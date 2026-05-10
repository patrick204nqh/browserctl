# frozen_string_literal: true

require "tmpdir"
require "browserctl/recording"

RSpec.describe Browserctl::Recording::State do
  around do |example|
    Dir.mktmpdir do |dir|
      @tmp_dir = dir
      example.run
    end
  end

  before do
    stub_const("Browserctl::Recording::STATE_FILE", File.join(@tmp_dir, "active_recording"))
  end

  describe ".active" do
    it "returns nil when no marker file is present" do
      expect(described_class.active).to be_nil
    end

    it "returns the recording name when the marker exists" do
      File.write(Browserctl::Recording::STATE_FILE, "my_flow\n")
      expect(described_class.active).to eq("my_flow")
    end

    it "strips trailing whitespace" do
      File.write(Browserctl::Recording::STATE_FILE, "my_flow\n\n")
      expect(described_class.active).to eq("my_flow")
    end
  end

  describe ".write" do
    it "creates the parent directory and writes the marker" do
      nested = File.join(@tmp_dir, "nested", "active_recording")
      stub_const("Browserctl::Recording::STATE_FILE", nested)

      described_class.write("scrape_issues")

      expect(File.read(nested)).to eq("scrape_issues")
    end

    it "returns the recording name" do
      expect(described_class.write("scrape_issues")).to eq("scrape_issues")
    end
  end

  describe ".clear!" do
    it "removes the marker and returns the recording name" do
      described_class.write("scrape_issues")
      expect(described_class.clear!).to eq("scrape_issues")
      expect(described_class.active).to be_nil
    end

    it "raises Browserctl::Error when no recording is active" do
      expect { described_class.clear! }
        .to raise_error(Browserctl::Error, /no active recording/)
    end
  end
end

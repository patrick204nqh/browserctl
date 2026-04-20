# frozen_string_literal: true

require "tmpdir"
require "browserctl/recording"

RSpec.describe Browserctl::Recording do
  around do |example|
    Dir.mktmpdir do |dir|
      @tmp_dir = dir
      example.run
    end
  end

  before do
    stub_const("Browserctl::Recording::RECORDINGS_DIR", @tmp_dir)
    stub_const("Browserctl::Recording::STATE_FILE",     File.join(@tmp_dir, "active_recording"))
  end

  describe ".start and .active" do
    it "creates a state file with the recording name" do
      described_class.start("my_flow")
      expect(described_class.active).to eq "my_flow"
    end
  end

  describe ".stop" do
    it "removes state file and returns name" do
      described_class.start("my_flow")
      name = described_class.stop
      expect(name).to eq "my_flow"
      expect(described_class.active).to be_nil
    end

    it "raises if no active recording" do
      expect { described_class.stop }.to raise_error(/no active recording/)
    end
  end

  describe ".append" do
    it "appends a JSON line for recordable commands" do
      described_class.start("test")
      described_class.append("fill", name: "login", selector: "input", value: "hi")
      lines = File.readlines(described_class.log_path("test"))
      expect(lines.length).to eq 1
      data = JSON.parse(lines.first, symbolize_names: true)
      expect(data[:cmd]).to eq "fill"
      expect(data[:value]).to eq "hi"
    end

    it "ignores non-recordable commands" do
      described_class.start("test")
      described_class.append("ping")
      expect(File.exist?(described_class.log_path("test"))).to be false
    end

    it "does nothing when no active recording" do
      described_class.append("click", name: "p", selector: "a")
      # no error, no file created
    end
  end

  describe ".generate_workflow" do
    it "produces valid Ruby workflow code from recorded commands" do
      described_class.start("checkout")
      described_class.append("open_page", name: "cart", url: "https://example.com/cart")
      described_class.append("click",     name: "cart", selector: "button#buy")
      described_class.stop
      ruby = described_class.generate_workflow("checkout")
      expect(ruby).to include('Browserctl.workflow "checkout"')
      expect(ruby).to include('page(:cart).goto("https://example.com/cart")')
      expect(ruby).to include('page(:cart).click("button#buy")')
    end
  end
end

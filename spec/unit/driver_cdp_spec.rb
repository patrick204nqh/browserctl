# frozen_string_literal: true

require "spec_helper"
require "browserctl/driver/cdp"

RSpec.describe Browserctl::Driver::CDP do
  describe "#supports?" do
    it "returns true for :devtools" do
      # Avoid actually launching a browser by not calling new directly;
      # test the method in isolation via a partial double
      driver = described_class.allocate
      expect(driver.supports?(:devtools)).to be true
    end

    it "returns false for unknown capabilities" do
      driver = described_class.allocate
      expect(driver.supports?(:webdriver)).to be false
      expect(driver.supports?(:something_else)).to be false
    end
  end

  describe "#headed?" do
    it "returns false when headless: true" do
      driver = described_class.allocate
      driver.instance_variable_set(:@headless, true)
      expect(driver.headed?).to be false
    end

    it "returns true when headless: false" do
      driver = described_class.allocate
      driver.instance_variable_set(:@headless, false)
      expect(driver.headed?).to be true
    end
  end

  describe "resolve_brave_path (private)" do
    let(:driver) { described_class.allocate }

    it "returns BRAVE_PATH env var when set" do
      with_env("BRAVE_PATH" => "/custom/brave") do
        expect(driver.send(:resolve_brave_path)).to eq("/custom/brave")
      end
    end

    it "aborts when no Brave binary is found and BRAVE_PATH is not set" do
      with_env("BRAVE_PATH" => nil) do
        # Stub all candidate paths to be non-executable
        allow(File).to receive(:executable?).and_return(false)
        expect { driver.send(:resolve_brave_path) }.to raise_error(SystemExit)
      end
    end
  end

  describe "detect_platform (private)" do
    let(:driver) { described_class.allocate }

    it "returns :darwin on macOS" do
      stub_const("RUBY_PLATFORM", "x86_64-darwin21")
      expect(driver.send(:detect_platform)).to eq(:darwin)
    end

    it "returns :linux on Linux" do
      stub_const("RUBY_PLATFORM", "x86_64-linux")
      expect(driver.send(:detect_platform)).to eq(:linux)
    end

    it "returns :windows on Windows" do
      stub_const("RUBY_PLATFORM", "x64-mingw32")
      expect(driver.send(:detect_platform)).to eq(:windows)
    end
  end
end

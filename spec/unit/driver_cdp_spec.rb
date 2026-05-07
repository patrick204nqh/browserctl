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

    it "returns BRAVE_PATH env var when it points to an executable" do
      with_env("BRAVE_PATH" => "/custom/brave") do
        allow(File).to receive(:executable?).with("/custom/brave").and_return(true)
        expect(driver.send(:resolve_brave_path)).to eq("/custom/brave")
      end
    end

    it "raises BrowserNotFound when BRAVE_PATH is set but not executable" do
      with_env("BRAVE_PATH" => "/typo/brave") do
        allow(File).to receive(:executable?).with("/typo/brave").and_return(false)
        expect { driver.send(:resolve_brave_path) }
          .to raise_error(Browserctl::BrowserNotFound, /not an executable/)
      end
    end

    it "raises BrowserNotFound when no Brave binary is found and BRAVE_PATH is not set" do
      with_env("BRAVE_PATH" => nil) do
        allow(File).to receive(:executable?).and_return(false)
        expect { driver.send(:resolve_brave_path) }
          .to raise_error(Browserctl::BrowserNotFound, /Brave browser not found/)
      end
    end
  end

  describe "resolve_chromium_path (private)" do
    let(:driver) { described_class.allocate }

    it "returns CHROMIUM_PATH env var when it points to an executable" do
      with_env("CHROMIUM_PATH" => "/custom/chromium") do
        allow(File).to receive(:executable?).with("/custom/chromium").and_return(true)
        expect(driver.send(:resolve_chromium_path)).to eq("/custom/chromium")
      end
    end

    it "returns nil when CHROMIUM_PATH is not set" do
      with_env("CHROMIUM_PATH" => nil) do
        expect(driver.send(:resolve_chromium_path)).to be_nil
      end
    end

    it "raises BrowserNotFound when CHROMIUM_PATH is set but not executable" do
      with_env("CHROMIUM_PATH" => "/typo/chromium") do
        allow(File).to receive(:executable?).with("/typo/chromium").and_return(false)
        expect { driver.send(:resolve_chromium_path) }
          .to raise_error(Browserctl::BrowserNotFound, /not an executable/)
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

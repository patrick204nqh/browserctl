# frozen_string_literal: true

require "spec_helper"
require "browserctl/client/recording_interceptor"

RSpec.describe Browserctl::Client::RecordingInterceptor do
  let(:recording) { double("Recording", active: false, append: nil) }
  subject(:interceptor) { described_class.new(recording: recording) }

  describe "#active?" do
    it "delegates to the injected recording module" do
      allow(recording).to receive(:active).and_return("flow-name")
      expect(interceptor.active?).to eq("flow-name")
    end

    it "returns nil/false when recording is off" do
      allow(recording).to receive(:active).and_return(nil)
      expect(interceptor.active?).to be_falsey
    end
  end

  describe "#capture_post_snapshot_flag" do
    it "returns true when active" do
      allow(recording).to receive(:active).and_return("flow")
      expect(interceptor.capture_post_snapshot_flag).to be(true)
    end

    it "returns nil when inactive" do
      allow(recording).to receive(:active).and_return(nil)
      expect(interceptor.capture_post_snapshot_flag).to be_nil
    end
  end

  describe "#append" do
    it "is a no-op when response is not ok" do
      expect(recording).not_to receive(:append)
      interceptor.append("click", response: { ok: false, error: "boom" }, params: { name: "x" })
    end

    it "calls Recording.append with cmd, response: and spreads params:" do
      response = { ok: true, value: 1 }
      expect(recording).to receive(:append)
        .with("fill", response: response, name: "main", selector: "input", value: "hi")
      interceptor.append("fill",
                         response: response,
                         params: { name: "main", selector: "input", value: "hi" })
    end

    it "handles missing params (empty hash)" do
      response = { ok: true }
      expect(recording).to receive(:append).with("ping", response: response)
      interceptor.append("ping", response: response)
    end
  end

  describe "default constructor" do
    it "defaults to the Browserctl::Recording module" do
      default = described_class.new
      expect(default.instance_variable_get(:@recording)).to eq(Browserctl::Recording)
    end
  end
end

# frozen_string_literal: true

require "spec_helper"
require "browserctl/workflow"

RSpec.describe Browserctl::WorkflowContext, "#assert_snapshot_stable" do
  let(:client) { instance_double(Browserctl::Client) }
  let(:snapshot) { [{ selector: "#a", role: "button", tag: "button" }] }
  let(:digest) { Browserctl::Replay::SnapshotDiff.digest(snapshot) }

  before do
    allow(client).to receive(:snapshot).with("main", format: "elements")
                                       .and_return({ snapshot: snapshot })
  end

  context "without a replay context (normal run)" do
    let(:ctx) { described_class.new({}, client) }

    it "passes silently when digests match" do
      expect { ctx.assert_snapshot_stable(:main, expected_digest: digest) }.not_to raise_error
    end

    it "raises WorkflowError when digests differ" do
      expect { ctx.assert_snapshot_stable(:main, expected_digest: "deadbeef") }
        .to raise_error(Browserctl::WorkflowError, /post-snapshot mismatch on :main/)
    end
  end

  context "with a replay context (workflow run --check)" do
    let(:replay_ctx) { Browserctl::Replay::Context.new }
    let(:ctx) { described_class.new({}, client, replay_context: replay_ctx) }

    it "records a drift event and does not raise on mismatch" do
      expect { ctx.assert_snapshot_stable(:main, expected_digest: "deadbeef") }
        .to output(/post-snapshot mismatch/).to_stderr
      expect(replay_ctx.drift_events.size).to eq(1)
      expect(replay_ctx.drift_events.first.reason).to eq("post-snapshot mismatch")
      expect(replay_ctx.drift_events.first.command).to eq(:assert_snapshot_stable)
    end

    it "is silent when the digest matches" do
      expect { ctx.assert_snapshot_stable(:main, expected_digest: digest) }.not_to output.to_stderr
      expect(replay_ctx.drift_events).to be_empty
    end
  end
end

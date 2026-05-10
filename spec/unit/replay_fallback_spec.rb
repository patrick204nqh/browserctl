# frozen_string_literal: true

require "spec_helper"
require "browserctl/workflow"
require "browserctl/replay/context"

RSpec.describe Browserctl::PageProxy, "selector_not_found fallback" do
  let(:client)  { instance_double(Browserctl::Client) }
  let(:context) { Browserctl::Replay::Context.new(fingerprints: { "form .submit-old" => recorded_fp }) }
  let(:proxy)   { described_class.new("login", client, replay_context: context) }

  let(:recorded_fp) do
    { text: "Sign in", role: "button", neighbors: ["input:"], position: { index: 5, depth: 4 } }
  end

  let(:live_snapshot) do
    [
      { ref: "ea11111", tag: "input", selector: "input.email",
        fingerprint: { text: "you@example.com", role: "textbox", neighbors: [], position: { index: 1, depth: 4 } } },
      { ref: "eb22222", tag: "button", selector: "form.v2 .btn-primary",
        fingerprint: { text: "Sign in", role: "button", neighbors: ["input:"], position: { index: 5, depth: 4 } } }
    ]
  end

  describe "#click" do
    it "rematches via fingerprint when selector fails and retries by ref" do
      expect(client).to receive(:click).with("login", "form .submit-old", ref: nil)
                                       .and_return({ error: "selector not found: form .submit-old",
                                                     code: Browserctl::Error::Codes::SELECTOR_NOT_FOUND })
      expect(client).to receive(:snapshot).with("login", format: "elements")
                                          .and_return({ ok: true, snapshot: live_snapshot })
      expect(client).to receive(:click).with("login", nil, ref: "eb22222").and_return({ ok: true })

      expect { proxy.click("form .submit-old") }.not_to raise_error
      expect(context.drift_events.size).to eq(1)
      expect(context.drift_events.first.matched_ref).to eq("eb22222")
      expect(context.drift_events.first.score).to be >= 0.6
    end

    it "raises the original error when no fingerprint is registered for the selector" do
      ctx = Browserctl::Replay::Context.new(fingerprints: {})
      proxy = described_class.new("login", client, replay_context: ctx)
      expect(client).to receive(:click).with("login", "form .other", ref: nil)
                                       .and_return({ error: "selector not found: form .other",
                                                     code: Browserctl::Error::Codes::SELECTOR_NOT_FOUND })

      expect { proxy.click("form .other") }.to raise_error(Browserctl::WorkflowError, /selector not found/)
      expect(ctx.drift_events).to be_empty
    end

    it "raises the original error when the matcher finds no candidate above threshold" do
      cold_snapshot = [
        { ref: "ec99999", tag: "button", selector: "x",
          fingerprint: { text: "Cancel", role: "link", neighbors: [], position: { index: 0, depth: 0 } } }
      ]
      expect(client).to receive(:click).with("login", "form .submit-old", ref: nil)
                                       .and_return({ error: "selector not found: form .submit-old",
                                                     code: Browserctl::Error::Codes::SELECTOR_NOT_FOUND })
      expect(client).to receive(:snapshot).and_return({ ok: true, snapshot: cold_snapshot })

      expect { proxy.click("form .submit-old") }.to raise_error(Browserctl::WorkflowError)
      expect(context.drift_events.first.reason).to eq("no candidate above threshold")
      expect(context.drift_events.first.matched_ref).to be_nil
    end

    it "does not attempt fallback when no replay context is attached" do
      bare = described_class.new("login", client)
      expect(client).to receive(:click).once
                                       .and_return({ error: "selector not found: x",
                                                     code: Browserctl::Error::Codes::SELECTOR_NOT_FOUND })
      expect(client).not_to receive(:snapshot)
      expect { bare.click("x") }.to raise_error(Browserctl::WorkflowError)
    end

    it "does not attempt fallback for ref-driven calls" do
      expect(client).to receive(:click).with("login", nil, ref: "eb22222")
                                       .and_return({ ok: true })
      expect(client).not_to receive(:snapshot)
      proxy.click(ref: "eb22222")
    end
  end

  describe "#fill" do
    it "passes the value through on rematch retry" do
      input_fp = { text: "you@example.com", role: "textbox", neighbors: [], position: { index: 1, depth: 4 } }
      ctx = Browserctl::Replay::Context.new(fingerprints: { "input.old" => input_fp })
      proxy = described_class.new("login", client, replay_context: ctx)

      expect(client).to receive(:fill).with("login", "input.old", "me@example.com", ref: nil)
                                      .and_return({ error: "selector not found: input.old",
                                                    code: Browserctl::Error::Codes::SELECTOR_NOT_FOUND })
      expect(client).to receive(:snapshot).and_return({ ok: true, snapshot: live_snapshot })
      expect(client).to receive(:fill).with("login", nil, "me@example.com", ref: "ea11111")
                                      .and_return({ ok: true })

      proxy.fill("input.old", "me@example.com")
    end
  end
end

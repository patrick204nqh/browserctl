# frozen_string_literal: true

require "spec_helper"
require "browserctl/replay/fingerprint_matcher"

RSpec.describe Browserctl::Replay::FingerprintMatcher do
  subject(:matcher) { described_class.new }

  def entry(ref:, text:, role:, neighbors: [], position: { index: 0, depth: 1 })
    { ref: ref, fingerprint: { text: text, role: role, neighbors: neighbors, position: position } }
  end

  describe "#best" do
    let(:target) do
      { text: "Sign in", role: "button", neighbors: ["input:", "a:Forgot password?"],
        position: { index: 7, depth: 4 } }
    end

    it "returns the exact match when present" do
      candidates = [
        entry(ref: "a", text: "Cancel", role: "button"),
        entry(ref: "b", text: "Sign in", role: "button",
              neighbors: ["input:", "a:Forgot password?"], position: { index: 7, depth: 4 }),
        entry(ref: "c", text: "Submit", role: "button")
      ]
      result = matcher.best(target, candidates)
      expect(result.candidate[:ref]).to eq("b")
      expect(result.score).to be_within(0.001).of(1.0)
    end

    it "tolerates neighbor and position drift when text+role agree" do
      candidates = [
        entry(ref: "a", text: "Cancel", role: "button"),
        entry(ref: "b", text: "Sign in", role: "button",
              neighbors: ["input:"], position: { index: 9, depth: 5 })
      ]
      result = matcher.best(target, candidates)
      expect(result.candidate[:ref]).to eq("b")
      expect(result.score).to be >= 0.6
    end

    it "returns nil when no candidate clears the threshold" do
      candidates = [
        entry(ref: "a", text: "Cancel", role: "button"),
        entry(ref: "b", text: "Submit", role: "link")
      ]
      expect(matcher.best(target, candidates)).to be_nil
    end

    it "returns nil for an empty candidate list" do
      expect(matcher.best(target, [])).to be_nil
    end

    it "respects an injected threshold" do
      strict = described_class.new(threshold: 0.95)
      partial = entry(ref: "p", text: "Sign in", role: "button",
                      neighbors: [], position: { index: 99, depth: 99 })
      expect(strict.best(target, [partial])).to be_nil
    end
  end

  describe "#score" do
    it "is 0.0 when both fingerprints are nil/empty" do
      expect(matcher.score(nil, {})).to eq(0.0)
    end

    it "is case-insensitive for text" do
      a = { text: "Sign In",  role: "button", neighbors: [], position: { index: 0, depth: 0 } }
      b = { text: "sign in",  role: "button", neighbors: [], position: { index: 0, depth: 0 } }
      expect(matcher.score(a, b)).to be_within(0.001).of(0.4 + 0.2 + 0.25 + 0.15)
    end
  end
end

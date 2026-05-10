# frozen_string_literal: true

require "spec_helper"
require "browserctl/replay/fingerprint_matcher"

# Gap-coverage specs for FingerprintMatcher. The pre-existing
# `spec/unit/fingerprint_matcher_spec.rb` covers happy-path #best and one
# #score case. These focus on algorithmic edge cases: weight bounds,
# determinism, monotonicity, and graceful handling of degenerate input.
RSpec.describe Browserctl::Replay::FingerprintMatcher do
  subject(:matcher) { described_class.new }

  let(:base_fp) do
    { text: "Sign in", role: "button",
      neighbors: %w[input: a:Forgot], position: { index: 3, depth: 4 } }
  end

  describe "#score bounds and determinism" do
    it "is bounded in [0.0, 1.0] for any plausible input" do
      a = base_fp
      b = { text: "Sign in", role: "button", neighbors: %w[input: a:Forgot],
            position: { index: 3, depth: 4 } }
      expect(matcher.score(a, b)).to be_between(0.0, 1.0).inclusive
    end

    it "returns exactly 1.0 for an exact fingerprint match" do
      expect(matcher.score(base_fp, base_fp.dup)).to be_within(1e-9).of(1.0)
    end

    it "is deterministic across repeated calls (no rand, no time leak)" do
      first = matcher.score(base_fp, base_fp.dup)
      10.times { expect(matcher.score(base_fp, base_fp.dup)).to eq(first) }
    end

    it "is symmetric: score(a, b) == score(b, a)" do
      a = base_fp
      b = { text: "Sign In", role: "button", neighbors: %w[input:],
            position: { index: 5, depth: 4 } }
      expect(matcher.score(a, b)).to be_within(1e-9).of(matcher.score(b, a))
    end
  end

  describe "#score graceful degeneracy" do
    it "returns 0.0 when target is nil" do
      expect(matcher.score(nil, base_fp)).to eq(0.0)
    end

    it "returns 0.0 when candidate is nil" do
      expect(matcher.score(base_fp, nil)).to eq(0.0)
    end

    it "does not crash when text is missing entirely" do
      a = { role: "button", neighbors: [], position: { index: 0, depth: 0 } }
      b = { role: "button", neighbors: [], position: { index: 0, depth: 0 } }
      # text=0.0, role=1.0, neighbors=1.0 (both empty), position=1.0 → 0.6
      expect(matcher.score(a, b)).to be_within(1e-9).of(0.6)
    end

    it "treats two empty neighbor arrays as a perfect Jaccard (1.0)" do
      a = base_fp.merge(neighbors: [])
      b = base_fp.merge(neighbors: [])
      # all four components match → 1.0
      expect(matcher.score(a, b)).to be_within(1e-9).of(1.0)
    end

    it "treats one empty + one non-empty neighbor list as Jaccard 0.0" do
      a = base_fp.merge(neighbors: [])
      b = base_fp.merge(neighbors: ["input:"])
      # text+role+position all match (0.40+0.20+0.15=0.75), neighbors=0
      expect(matcher.score(a, b)).to be_within(1e-9).of(0.75)
    end
  end

  describe "#score monotonicity" do
    it "decreases monotonically as position drifts further" do
      near = base_fp.merge(position: { index: 4, depth: 4 })
      mid  = base_fp.merge(position: { index: 6, depth: 4 })
      far  = base_fp.merge(position: { index: 9, depth: 9 })
      s_near = matcher.score(base_fp, near)
      s_mid  = matcher.score(base_fp, mid)
      s_far  = matcher.score(base_fp, far)
      expect(s_near).to be > s_mid
      expect(s_mid).to be >= s_far
    end

    it "scores text mismatch lower than neighbor-only mismatch" do
      text_diff = base_fp.merge(text: "Cancel")
      nbr_diff  = base_fp.merge(neighbors: ["nope:"])
      expect(matcher.score(base_fp, text_diff)).to be < matcher.score(base_fp, nbr_diff)
    end
  end

  describe "#best edge cases" do
    it "picks the higher-scoring candidate when several clear threshold" do
      target = base_fp
      cands = [
        { ref: "lo", fingerprint: base_fp.merge(neighbors: ["input:"]) },
        { ref: "hi", fingerprint: base_fp.dup }
      ]
      expect(matcher.best(target, cands).candidate[:ref]).to eq("hi")
    end

    it "returns a Match struct exposing candidate and score" do
      target = base_fp
      cands  = [{ ref: "x", fingerprint: base_fp.dup }]
      m = matcher.best(target, cands)
      expect(m).to respond_to(:candidate, :score)
      expect(m.candidate[:ref]).to eq("x")
    end
  end
end

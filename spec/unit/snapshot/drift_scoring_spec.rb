# frozen_string_literal: true

require "spec_helper"
require "browserctl/replay/snapshot_diff"

# Gap-coverage specs for SnapshotDiff (drift scoring). The existing
# `spec/unit/replay_snapshot_diff_spec.rb` covers digest stability and a
# basic compare. These add: zero-drift identity, asymmetric add/remove
# accounting, monotonicity (more changes → bigger diff), digest length /
# format invariants, and degenerate empty inputs.
#
# Note: v0.11 SnapshotDiff is not a numeric drift score — it returns
# {added:, removed:} sets and a hex digest. We treat "drift = size of
# the symmetric difference" for monotonicity assertions, since that is
# the contract callers (replay_telemetry) actually rely on.
RSpec.describe Browserctl::Replay::SnapshotDiff do
  let(:el_a) { { selector: "#a", role: "button", tag: "button" } }
  let(:el_b) { { selector: "#b", role: "link",   tag: "a" } }
  let(:el_c) { { selector: "#c", role: "img",    tag: "img" } }
  let(:el_d) { { selector: "#d", role: "textbox", tag: "input" } }

  def drift_size(diff)
    diff[:added].size + diff[:removed].size
  end

  describe ".compare drift accounting" do
    it "reports zero drift for identical snapshots" do
      diff = described_class.compare([el_a, el_b], [el_a, el_b])
      expect(drift_size(diff)).to eq(0)
    end

    it "reports zero drift even when element order differs" do
      diff = described_class.compare([el_a, el_b], [el_b, el_a])
      expect(drift_size(diff)).to eq(0)
    end

    it "reports a small non-zero drift for a single removed element" do
      diff = described_class.compare([el_a, el_b], [el_a])
      expect(diff[:added]).to be_empty
      expect(diff[:removed]).to eq(["#b"])
    end

    it "reports asymmetric drift: addition vs removal of the same element" do
      add_diff = described_class.compare([el_a], [el_a, el_b])
      rem_diff = described_class.compare([el_a, el_b], [el_a])
      expect(add_diff).to eq(added: ["#b"], removed: [])
      expect(rem_diff).to eq(added: [], removed: ["#b"])
    end

    it "scales with number of changes (monotonicity)" do
      one  = described_class.compare([el_a], [el_a, el_b])
      two  = described_class.compare([el_a], [el_a, el_b, el_c])
      many = described_class.compare([el_a], [el_a, el_b, el_c, el_d])
      expect(drift_size(one)).to be < drift_size(two)
      expect(drift_size(two)).to be < drift_size(many)
    end

    it "handles two empty snapshots without division-by-zero" do
      expect { described_class.compare([], []) }
        .not_to raise_error
      expect(described_class.compare([], [])).to eq(added: [], removed: [])
    end

    it "handles nil snapshots as empty (no crash)" do
      expect(described_class.compare(nil, [el_a])).to eq(added: ["#a"], removed: [])
      expect(described_class.compare([el_a], nil)).to eq(added: [], removed: ["#a"])
    end

    it "returns sorted added/removed lists for deterministic output" do
      diff = described_class.compare([el_a], [el_a, el_d, el_b, el_c])
      expect(diff[:added]).to eq(diff[:added].sort)
    end
  end

  describe ".digest format and stability" do
    it "produces a 16-char lowercase hex digest" do
      digest = described_class.digest([el_a, el_b])
      expect(digest).to match(/\A[0-9a-f]{16}\z/)
    end

    it "is deterministic across repeated calls" do
      first = described_class.digest([el_a, el_b])
      5.times { expect(described_class.digest([el_a, el_b])).to eq(first) }
    end

    it "produces a non-nil digest for an empty snapshot (zero elements still hashes)" do
      # Distinct from nil input; empty-array is a valid snapshot and digest is the hash of the empty join.
      expect(described_class.digest([])).to match(/\A[0-9a-f]{16}\z/)
    end

    it "ignores entries missing a selector (treated as noise)" do
      noisy = [el_a, { role: "button", tag: "button" }, el_b]
      expect(described_class.digest(noisy)).to eq(described_class.digest([el_a, el_b]))
    end
  end
end

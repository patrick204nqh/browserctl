# frozen_string_literal: true

require "spec_helper"
require "browserctl/replay/snapshot_diff"

RSpec.describe Browserctl::Replay::SnapshotDiff do
  let(:snap_a) do
    [
      { selector: "#a", role: "button", tag: "button" },
      { selector: "#b", role: "link",   tag: "a" }
    ]
  end
  let(:snap_b_reordered) do
    [
      { selector: "#b", role: "link",   tag: "a" },
      { selector: "#a", role: "button", tag: "button" }
    ]
  end
  let(:snap_c_added) do
    snap_a + [{ selector: "#c", role: "img", tag: "img" }]
  end

  describe ".digest" do
    it "returns nil for nil input" do
      expect(described_class.digest(nil)).to be_nil
    end

    it "is stable under element ordering" do
      expect(described_class.digest(snap_a)).to eq(described_class.digest(snap_b_reordered))
    end

    it "changes when an element is added" do
      expect(described_class.digest(snap_a)).not_to eq(described_class.digest(snap_c_added))
    end

    it "skips entries without a selector" do
      noisy = snap_a + [{ role: "button", tag: "button" }] # no selector
      expect(described_class.digest(noisy)).to eq(described_class.digest(snap_a))
    end

    it "accepts string-keyed snapshots from JSON" do
      stringy = snap_a.map { |h| h.transform_keys(&:to_s) }
      expect(described_class.digest(stringy)).to eq(described_class.digest(snap_a))
    end
  end

  describe ".compare" do
    it "reports added and removed selectors" do
      diff = described_class.compare(snap_a, snap_c_added)
      expect(diff).to eq(added: ["#c"], removed: [])
    end

    it "is empty when snapshots are identical" do
      expect(described_class.compare(snap_a, snap_b_reordered)).to eq(added: [], removed: [])
    end
  end
end

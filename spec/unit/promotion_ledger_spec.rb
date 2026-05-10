# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "browserctl/workflow/promotion_ledger"

RSpec.describe Browserctl::Workflow::PromotionLedger do
  around do |example|
    Dir.mktmpdir do |dir|
      @ledger = File.join(dir, "check_ledger.jsonl")
      example.run
    end
  end

  describe ".record" do
    it "appends a JSONL line per call" do
      described_class.record(workflow: "wf", verdict: :clean, path: @ledger)
      described_class.record(workflow: "wf", verdict: :drift, path: @ledger)

      lines = File.readlines(@ledger).map { |l| JSON.parse(l) }
      expect(lines.size).to eq(2)
      expect(lines[0]).to include("workflow" => "wf", "verdict" => "clean")
      expect(lines[1]).to include("workflow" => "wf", "verdict" => "drift")
      expect(lines[0]["ts"]).to match(/\d{4}-\d{2}-\d{2}T/)
    end

    it "ignores unknown verdicts" do
      described_class.record(workflow: "wf", verdict: :weird, path: @ledger)
      expect(File.exist?(@ledger)).to be(false)
    end

    it "creates the parent directory if missing" do
      nested = File.join(File.dirname(@ledger), "deep", "log.jsonl")
      described_class.record(workflow: "wf", verdict: :clean, path: nested)
      expect(File.exist?(nested)).to be(true)
    end
  end

  describe ".clean_streak" do
    it "returns 0 when the ledger does not exist" do
      expect(described_class.clean_streak(workflow: "wf", path: @ledger)).to eq(0)
    end

    it "counts a trailing run of clean verdicts" do
      3.times { described_class.record(workflow: "wf", verdict: :clean, path: @ledger) }
      expect(described_class.clean_streak(workflow: "wf", path: @ledger)).to eq(3)
    end

    it "resets the streak when drift or fail appears" do
      described_class.record(workflow: "wf", verdict: :clean, path: @ledger)
      described_class.record(workflow: "wf", verdict: :drift, path: @ledger)
      described_class.record(workflow: "wf", verdict: :clean, path: @ledger)
      expect(described_class.clean_streak(workflow: "wf", path: @ledger)).to eq(1)

      described_class.record(workflow: "wf", verdict: :fail, path: @ledger)
      described_class.record(workflow: "wf", verdict: :clean, path: @ledger)
      described_class.record(workflow: "wf", verdict: :clean, path: @ledger)
      expect(described_class.clean_streak(workflow: "wf", path: @ledger)).to eq(2)
    end

    it "scopes to the named workflow" do
      described_class.record(workflow: "a", verdict: :clean, path: @ledger)
      described_class.record(workflow: "b", verdict: :fail, path: @ledger)
      described_class.record(workflow: "a", verdict: :clean, path: @ledger)
      expect(described_class.clean_streak(workflow: "a", path: @ledger)).to eq(2)
      expect(described_class.clean_streak(workflow: "b", path: @ledger)).to eq(0)
    end

    it "skips malformed lines without raising" do
      File.write(@ledger, "{not json}\n")
      described_class.record(workflow: "wf", verdict: :clean, path: @ledger)
      expect(described_class.clean_streak(workflow: "wf", path: @ledger)).to eq(1)
    end
  end
end

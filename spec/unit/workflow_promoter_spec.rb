# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "browserctl/workflow/promoter"

RSpec.describe Browserctl::Workflow::Promoter do
  around do |example|
    Dir.mktmpdir do |dir|
      @tmp = dir
      @source_dir = File.join(dir, "src")
      @target_dir = File.join(dir, "target")
      @ledger     = File.join(dir, "ledger.jsonl")
      FileUtils.mkdir_p(@source_dir)
      File.write(File.join(@source_dir, "wf.rb"), "# workflow body\n")
      example.run
    end
  end

  before do
    stub_const("Browserctl::BROWSERCTL_DIR", @target_dir)
  end

  def record_clean(workflow, count)
    count.times { Browserctl::Workflow::PromotionLedger.record(workflow: workflow, verdict: :clean, path: @ledger) }
  end

  it "promotes a workflow when the streak meets the threshold" do
    record_clean("wf", 3)
    result = described_class.promote(
      workflow: "wf", source_dir: @source_dir, ledger_path: @ledger
    )
    expect(File.exist?(File.join(@target_dir, "workflows", "wf.rb"))).to be(true)
    expect(result).to include(workflow: "wf", streak: 3, threshold: 3, forced: false)
  end

  it "leaves the source file in place after promote (copy, not move)" do
    record_clean("wf", 3)
    described_class.promote(workflow: "wf", source_dir: @source_dir, ledger_path: @ledger)
    expect(File.exist?(File.join(@source_dir, "wf.rb"))).to be(true)
  end

  it "raises IneligibleError when streak is below threshold" do
    record_clean("wf", 2)
    expect do
      described_class.promote(workflow: "wf", source_dir: @source_dir, ledger_path: @ledger)
    end.to raise_error(described_class::IneligibleError, /2 clean.*needs 3/)
  end

  it "honours --force even when ineligible" do
    record_clean("wf", 0)
    result = described_class.promote(
      workflow: "wf", force: true, source_dir: @source_dir, ledger_path: @ledger
    )
    expect(result[:forced]).to be(true)
    expect(File.exist?(File.join(@target_dir, "workflows", "wf.rb"))).to be(true)
  end

  it "respects a custom --threshold" do
    record_clean("wf", 1)
    expect do
      described_class.promote(
        workflow: "wf", threshold: 1, source_dir: @source_dir, ledger_path: @ledger
      )
    end.not_to raise_error
  end

  it "raises NotFoundError when the source file does not exist" do
    expect do
      described_class.promote(workflow: "missing", source_dir: @source_dir, ledger_path: @ledger)
    end.to raise_error(described_class::NotFoundError, /missing/)
  end

  it "does not count drift runs toward the streak" do
    record_clean("wf", 2)
    Browserctl::Workflow::PromotionLedger.record(workflow: "wf", verdict: :drift, path: @ledger)
    record_clean("wf", 2)
    expect do
      described_class.promote(workflow: "wf", source_dir: @source_dir, ledger_path: @ledger)
    end.to raise_error(described_class::IneligibleError, /2 clean/)
  end
end

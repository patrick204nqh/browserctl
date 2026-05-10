# frozen_string_literal: true

require "spec_helper"
require "json"
require "tmpdir"
require "browserctl/replay/context"
require "browserctl/replay/telemetry"

RSpec.describe Browserctl::Replay::Telemetry do
  let(:tmpdir) { Dir.mktmpdir }
  let(:path)   { File.join(tmpdir, "replay_drift.jsonl") }

  after { FileUtils.remove_entry(tmpdir) if File.directory?(tmpdir) }

  it "writes one JSONL line per drift event" do
    ctx = Browserctl::Replay::Context.new
    ctx.record(command: :click, selector: ".old", matched_ref: "ea1", score: 0.91, reason: "rematch")
    ctx.record(command: :fill, selector: "#email", matched_ref: nil,
               score: 0.40, reason: "no candidate above threshold")

    written = described_class.emit(ctx, workflow: "demo", path: path)
    expect(written).to eq(2)

    lines = File.readlines(path).map { |l| JSON.parse(l) }
    expect(lines.size).to eq(2)
    expect(lines[0]).to include(
      "event" => "replay_drift",
      "workflow" => "demo",
      "command" => "click",
      "selector" => ".old",
      "matched_ref" => "ea1",
      "score" => 0.91,
      "reason" => "rematch"
    )
    expect(lines[0]).to have_key("ts")
    expect(lines[1]["reason"]).to eq("no candidate above threshold")
  end

  it "appends to an existing log without truncating prior runs" do
    File.write(path, %({"event":"replay_drift","workflow":"prior"}\n))
    ctx = Browserctl::Replay::Context.new
    ctx.record(command: :click, selector: ".x", matched_ref: "ea2", score: 0.95, reason: "rematch")

    described_class.emit(ctx, workflow: "demo", path: path)
    lines = File.readlines(path)
    expect(lines.size).to eq(2)
    expect(JSON.parse(lines[0])["workflow"]).to eq("prior")
    expect(JSON.parse(lines[1])["workflow"]).to eq("demo")
  end

  it "is a no-op when there are no drift events" do
    ctx = Browserctl::Replay::Context.new
    expect(described_class.emit(ctx, workflow: "demo", path: path)).to eq(0)
    expect(File.exist?(path)).to be(false)
  end

  it "is a no-op when ctx is nil" do
    expect(described_class.emit(nil, workflow: "demo", path: path)).to eq(0)
    expect(File.exist?(path)).to be(false)
  end

  it "creates the log file with 0600 permissions on first write" do
    ctx = Browserctl::Replay::Context.new
    ctx.record(command: :click, selector: ".x", matched_ref: "ea2", score: 0.95, reason: "rematch")
    described_class.emit(ctx, workflow: "demo", path: path)
    mode = File.stat(path).mode & 0o777
    expect(mode).to eq(0o600)
  end
end

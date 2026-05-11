# frozen_string_literal: true

require "spec_helper"
require "browserctl/trace/event_stream"
require "json"
require "tmpdir"

RSpec.describe Browserctl::Trace::EventStream do
  let(:tmp_dir) { Dir.mktmpdir("browserctl-event-stream") }

  after { FileUtils.remove_entry(tmp_dir) if File.directory?(tmp_dir) }

  def write_log(name, records)
    File.open(File.join(tmp_dir, name), "w") do |f|
      records.each { |r| f.puts(JSON.generate(r)) }
    end
  end

  it "returns no records when log directory is empty" do
    stream = described_class.new(tmp_dir)
    expect(stream.empty?).to be true
    expect(stream.to_a).to eq([])
  end

  it "parses JSONL lines from cli.log + daemon.log and sorts by ts" do
    write_log("daemon.log", [
                { ts: "2026-05-10T06:00:02.000Z", event: "b" },
                { ts: "2026-05-10T06:00:00.000Z", event: "a" }
              ])
    write_log("cli.log", [
                { ts: "2026-05-10T06:00:01.000Z", event: "mid" }
              ])

    events = described_class.new(tmp_dir).to_a
    expect(events.map { |r| r["event"] }).to eq(%w[a mid b])
  end

  it "skips malformed JSON lines and blank lines" do
    File.open(File.join(tmp_dir, "daemon.log"), "w") do |f|
      f.puts("not json")
      f.puts("")
      f.puts(JSON.generate(ts: "2026-05-10T06:00:00.000Z", event: "ok"))
    end

    events = described_class.new(tmp_dir).to_a
    expect(events.length).to eq(1)
    expect(events.first["event"]).to eq("ok")
  end

  it "filters to a specific session when session_filter is provided" do
    write_log("daemon.log", [
                { ts: "2026-05-10T06:00:00.000Z", event: "a", session_id: "s1" },
                { ts: "2026-05-10T06:00:01.000Z", event: "b", session_id: "s2" }
              ])

    events = described_class.new(tmp_dir, session_filter: "s2").to_a
    expect(events.map { |r| r["event"] }).to eq(["b"])
  end

  it "scopes to the most recent session_id when none is specified" do
    write_log("daemon.log", [
                { ts: "2026-05-10T06:00:00.000Z", event: "a", session_id: "old" },
                { ts: "2026-05-10T06:00:01.000Z", event: "b", session_id: "recent" }
              ])

    events = described_class.new(tmp_dir).to_a
    expect(events.map { |r| r["event"] }).to eq(["b"])
  end

  it "returns all records when no record carries a session_id" do
    write_log("daemon.log", [
                { ts: "2026-05-10T06:00:00.000Z", event: "a" },
                { ts: "2026-05-10T06:00:01.000Z", event: "b" }
              ])

    events = described_class.new(tmp_dir).to_a
    expect(events.map { |r| r["event"] }).to eq(%w[a b])
  end
end

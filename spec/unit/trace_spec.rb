# frozen_string_literal: true

require "spec_helper"
require "browserctl/commands/trace"
require "json"
require "stringio"
require "tmpdir"

RSpec.describe Browserctl::Commands::Trace do
  let(:tmp_dir) { Dir.mktmpdir("browserctl-trace") }
  let(:out)     { StringIO.new }

  after { FileUtils.remove_entry(tmp_dir) if File.directory?(tmp_dir) }

  def write_log(name, records)
    File.open(File.join(tmp_dir, name), "w") do |f|
      records.each { |r| f.puts(JSON.generate(r)) }
    end
  end

  describe ".run" do
    it "prints an empty-state notice when no log files exist" do
      described_class.run([], log_dir: tmp_dir, out: out)
      expect(out.string).to include("No log entries found")
    end

    it "merges cli + daemon logs by timestamp and renders a timeline" do
      write_log("daemon.log", [
                  { ts: "2026-05-10T06:21:48.500Z", level: "INFO", component: "daemon", event: "ready", port: 1234 },
                  { ts: "2026-05-10T06:21:50.000Z", level: "ERROR", component: "daemon", msg: "kaboom" }
                ])
      write_log("cli.log", [
                  { ts: "2026-05-10T06:21:49.000Z", level: "INFO", component: "cli", event: "click",
                    selector: "#submit" }
                ])

      described_class.run([], log_dir: tmp_dir, out: out)
      lines = out.string.lines.map(&:rstrip)

      # Three records, ordered by ts.
      expect(lines.length).to eq(3)
      expect(lines[0]).to include("06:21:48.500", "daemon", "ready", "port=1234")
      expect(lines[1]).to include("06:21:49.000", "cli", "click", "selector=#submit")
      expect(lines[2]).to include("06:21:50.000", "ERROR", "kaboom")
    end

    it "tolerates malformed JSON lines without crashing" do
      File.open(File.join(tmp_dir, "daemon.log"), "w") do |f|
        f.puts("not json")
        f.puts(JSON.generate(ts: "2026-05-10T06:00:00.000Z", level: "INFO", component: "daemon", event: "ok"))
        f.puts("")
      end

      described_class.run([], log_dir: tmp_dir, out: out)
      expect(out.string.lines.length).to eq(1)
      expect(out.string).to include("ok")
    end

    it "filters by session_id when one is provided" do
      write_log("daemon.log", [
                  { ts: "2026-05-10T06:00:00.000Z", level: "INFO", component: "daemon",
                    event: "a", session_id: "s1" },
                  { ts: "2026-05-10T06:00:01.000Z", level: "INFO", component: "daemon",
                    event: "b", session_id: "s2" }
                ])

      described_class.run(["s2"], log_dir: tmp_dir, out: out)
      expect(out.string).to include("b")
      expect(out.string).not_to include("event=a")
    end

    it "categorises errors with an icon prefix in the rendered line" do
      write_log("daemon.log", [
                  { ts: "2026-05-10T06:00:00.000Z", level: "ERROR", component: "daemon", error: "boom" }
                ])

      described_class.run([], log_dir: tmp_dir, out: out)
      # Error category icon "!" appears between timestamp and level column.
      expect(out.string).to match(/06:00:00\.000\s+!\s+ERROR/)
    end

    it "does not emit ANSI colour codes when out is not a TTY" do
      write_log("cli.log", [
                  { ts: "2026-05-10T06:00:00.000Z", level: "INFO", component: "cli", event: "x" }
                ])

      described_class.run([], log_dir: tmp_dir, out: out)
      expect(out.string).not_to include("\e[")
    end
  end
end

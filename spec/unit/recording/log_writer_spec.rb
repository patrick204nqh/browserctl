# frozen_string_literal: true

require "tmpdir"
require "json"
require "browserctl/recording"

RSpec.describe Browserctl::Recording::LogWriter do
  around do |example|
    Dir.mktmpdir do |dir|
      @tmp_dir = dir
      example.run
    end
  end

  before do
    stub_const("Browserctl::Recording::RECORDINGS_DIR", @tmp_dir)
  end

  describe ".log_path" do
    it "returns the JSONL path under the recordings dir" do
      expect(described_class.log_path("scrape_issues"))
        .to eq(File.join(@tmp_dir, "scrape_issues.jsonl"))
    end
  end

  describe ".init_log" do
    it "creates the log with a _meta header carrying format and recording name" do
      described_class.init_log("scrape_issues")
      lines = File.readlines(described_class.log_path("scrape_issues"))
      expect(lines.size).to eq(1)
      meta = JSON.parse(lines.first)
      expect(meta["cmd"]).to eq("_meta")
      expect(meta["recording"]).to eq("scrape_issues")
      expect(meta["format_version"]).to eq(Browserctl::Recording::RECORDING_FORMAT_VERSION)
      expect(meta["log_format"]).to eq(Browserctl::Recording::LOG_FORMAT)
      expect(meta["started_at"]).to match(/\A\d{4}-\d{2}-\d{2}T/)
    end

    it "truncates an existing log" do
      path = described_class.log_path("scrape_issues")
      described_class.init_log("scrape_issues")
      File.open(path, "a") { |f| f.puts(JSON.generate(cmd: "noise")) }
      described_class.init_log("scrape_issues")
      lines = File.readlines(path)
      expect(lines.size).to eq(1)
    end

    it "locks the log to user-only permissions" do
      path = described_class.init_log("scrape_issues")
      mode = File.stat(path).mode & 0o777
      expect(mode).to eq(0o600)
    end
  end

  describe ".append_entry and .read_entries" do
    it "round-trips JSONL entries with symbolised keys" do
      described_class.init_log("scrape_issues")
      described_class.append_entry("scrape_issues", { cmd: "navigate", url: "https://example.com" })
      entries = described_class.read_entries("scrape_issues")
      expect(entries.size).to eq(2)
      expect(entries.last).to eq(cmd: "navigate", url: "https://example.com")
    end
  end

  describe ".delete_log" do
    it "removes the log file" do
      described_class.init_log("scrape_issues")
      path = described_class.log_path("scrape_issues")
      expect(File.exist?(path)).to be(true)
      described_class.delete_log("scrape_issues")
      expect(File.exist?(path)).to be(false)
    end

    it "is a no-op when the log is missing" do
      expect { described_class.delete_log("never_started") }.not_to raise_error
    end
  end

  describe ".verify_format_version!" do
    it "passes when the _meta header declares a supported version" do
      lines = [{ cmd: "_meta", format_version: Browserctl::Recording::RECORDING_FORMAT_VERSION }]
      expect { described_class.verify_format_version!(lines) }.not_to raise_error
    end

    it "raises ProtocolMismatch when the _meta header is missing" do
      expect { described_class.verify_format_version!([{ cmd: "navigate" }]) }
        .to raise_error(Browserctl::ProtocolMismatch, /missing format_version/)
    end

    it "raises ProtocolMismatch when the declared version is unsupported" do
      lines = [{ cmd: "_meta", format_version: 999 }]
      expect { described_class.verify_format_version!(lines, path: "/tmp/x.jsonl") }
        .to raise_error(Browserctl::ProtocolMismatch, /declares format_version=999/)
    end
  end
end

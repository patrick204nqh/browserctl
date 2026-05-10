# frozen_string_literal: true

require "spec_helper"
require "browserctl/logger"
require "json"
require "tmpdir"

RSpec.describe "Browserctl logger (structured JSONL)" do
  let(:tmp_home) { Dir.mktmpdir("browserctl-logs") }

  before do
    stub_const("Browserctl::BROWSERCTL_DIR", tmp_home)
    # Silence the stderr sink so test output stays clean.
    @null = File.open(File::NULL, "w")
    @orig_stderr = $stderr
    $stderr = @null
  end

  after do
    $stderr = @orig_stderr
    @null&.close
    FileUtils.remove_entry(tmp_home) if File.directory?(tmp_home)
  end

  describe Browserctl::JsonlFormatter do
    it "emits one JSON object per line with ts/level/component/msg fields" do
      fmt = described_class.new(component: "daemon")
      out = fmt.call("INFO", Time.utc(2026, 5, 10, 12, 0, 0), "browserd", "hello")

      expect(out).to end_with("\n")
      record = JSON.parse(out.chomp)
      expect(record).to include(
        "ts" => "2026-05-10T12:00:00.000Z",
        "level" => "INFO",
        "component" => "daemon",
        "msg" => "hello"
      )
    end

    it "merges hash messages so callers can attach structured context" do
      fmt = described_class.new(component: "cli")
      out = fmt.call("INFO", Time.utc(2026, 5, 10), "browserd", { msg: "click", selector: "#submit", page: "p1" })
      record = JSON.parse(out.chomp)
      expect(record).to include(
        "msg" => "click",
        "selector" => "#submit",
        "page" => "p1",
        "component" => "cli"
      )
    end

    it "captures exceptions with class, message, and a bounded backtrace" do
      fmt = described_class.new(component: "daemon")
      err = begin
        raise ArgumentError, "boom"
      rescue ArgumentError => e
        e
      end

      record = JSON.parse(fmt.call("ERROR", Time.now, "browserd", err).chomp)
      expect(record["msg"]).to eq("ArgumentError: boom")
      expect(record["backtrace"]).to be_an(Array)
      expect(record["backtrace"].length).to be <= 10
    end
  end

  describe ".build_logger" do
    it "writes a valid JSONL file under ~/.browserctl/logs/<component>.log" do
      logger = Browserctl.build_logger("debug", component: "daemon")
      logger.info(event: "ready", port: 1234)
      logger.error("kapow")

      path = File.join(Browserctl.log_dir, "daemon.log")
      expect(File).to exist(path)
      lines = File.readlines(path).map { |l| JSON.parse(l) }
      ready = lines.find { |r| r["event"] == "ready" }
      expect(ready).to include("component" => "daemon", "level" => "INFO", "port" => 1234)
      expect(lines.last).to include("level" => "ERROR", "msg" => "kapow")
    end

    it "respects --log-level by suppressing entries below the threshold" do
      logger = Browserctl.build_logger("warn", component: "cli")
      logger.debug("nope")
      logger.info("nope")
      logger.warn("yes-w")
      logger.error("yes-e")

      path = File.join(Browserctl.log_dir, "cli.log")
      lines = File.readlines(path).map { |l| JSON.parse(l) }
      levels = lines.map { |r| r["level"] }
      expect(levels).to all(satisfy { |lvl| %w[WARN ERROR].include?(lvl) })
      expect(levels).to include("WARN", "ERROR")
    end

    it "configures rotation (10 files x 10MB) on the JSONL sink" do
      expect(Browserctl::LOG_SHIFT_AGE).to eq(10)
      expect(Browserctl::LOG_SHIFT_SIZE).to eq(10 * 1024 * 1024)

      captured = nil
      original = Browserctl::HeaderlessLogDevice.method(:new)
      allow(Browserctl::HeaderlessLogDevice).to receive(:new) do |path, **kwargs|
        captured = { path: path, kwargs: kwargs }
        original.call(path, **kwargs)
      end

      Browserctl.build_logger("info", component: "daemon", jsonl: true)

      expect(captured[:path]).to eq(File.join(Browserctl.log_dir, "daemon.log"))
      expect(captured[:kwargs][:shift_age]).to eq(Browserctl::LOG_SHIFT_AGE)
      expect(captured[:kwargs][:shift_size]).to eq(Browserctl::LOG_SHIFT_SIZE)
    end

    it "writes a pure JSONL file with no '# Logfile created' header" do
      Browserctl.build_logger("info", component: "daemon").info("first")
      content = File.read(File.join(Browserctl.log_dir, "daemon.log"))
      expect(content).not_to start_with("#")
      expect { JSON.parse(content.lines.first) }.not_to raise_error
    end

    it "auto-creates the logs directory on first write" do
      FileUtils.rm_rf(Browserctl.log_dir)
      Browserctl.build_logger("info", component: "cli").info("init")
      expect(File).to exist(Browserctl.log_dir)
    end

    it "skips JSONL sink when jsonl: false (legacy callers)" do
      Browserctl.build_logger("info", component: "daemon", jsonl: false).info("nope")
      expect(File).not_to exist(File.join(Browserctl.log_dir, "daemon.log"))
    end
  end
end

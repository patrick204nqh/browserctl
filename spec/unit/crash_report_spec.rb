# frozen_string_literal: true

require "spec_helper"
require "browserctl/crash_report"
require "browserctl/errors"
require "json"
require "tmpdir"

RSpec.describe Browserctl::CrashReport do
  let(:tmp_home) { Dir.mktmpdir("browserctl-crash") }
  let(:log_dir)  { File.join(tmp_home, "logs") }
  let(:log_path) { File.join(log_dir, "daemon.log") }

  before do
    stub_const("Browserctl::BROWSERCTL_DIR", tmp_home)
    FileUtils.mkdir_p(log_dir)
  end

  after { FileUtils.remove_entry(tmp_home) if File.directory?(tmp_home) }

  def make_error(klass = RuntimeError, msg = "boom")
    raise klass, msg
  rescue klass => e
    e
  end

  it "writes a crash file with the documented schema" do
    err = make_error
    path = described_class.write(error: err, log_path: nil)

    expect(path).to start_with(log_dir)
    expect(File.basename(path)).to match(/\Acrash-\d{4}-\d{2}-\d{2}T.*\.json\z/)
    payload = JSON.parse(File.read(path))
    expect(payload).to include(
      "schema_version" => 1,
      "daemon_version" => Browserctl::VERSION,
      "ruby_version" => RUBY_VERSION
    )
    expect(payload["ts"]).to match(/\A\d{4}-\d{2}-\d{2}T.*Z\z/)
    expect(payload["os"]).to include("platform" => RUBY_PLATFORM)
    expect(payload["error"]).to include("class" => "RuntimeError", "message" => "boom")
    expect(payload["backtrace"]).to be_an(Array)
    expect(payload["last_events"]).to eq([])
  end

  it "passes through the error code for Browserctl::Error subclasses" do
    err = begin
      raise Browserctl::TimeoutError, "stuck"
    rescue Browserctl::TimeoutError => e
      e
    end
    path = described_class.write(error: err, log_path: nil)
    payload = JSON.parse(File.read(path))
    expect(payload["error"]).to include(
      "class" => "Browserctl::TimeoutError",
      "message" => "stuck",
      "code" => "timeout"
    )
  end

  it "tails the last 50 valid JSONL events from the daemon log" do
    File.open(log_path, "w") do |f|
      1.upto(75) do |i|
        f.puts JSON.generate(ts: "2026-05-10T12:00:#{format('%02d', i % 60)}.000Z",
                             level: "INFO", component: "daemon", msg: "event-#{i}", n: i)
      end
    end

    path = described_class.write(error: make_error, log_path: log_path)
    payload = JSON.parse(File.read(path))
    expect(payload["last_events"].length).to eq(50)
    expect(payload["last_events"].first).to include("n" => 26)
    expect(payload["last_events"].last).to include("n" => 75)
  end

  it "includes whatever events exist when fewer than 50 are present" do
    File.open(log_path, "w") do |f|
      1.upto(3) { |i| f.puts JSON.generate(msg: "event-#{i}") }
    end
    path = described_class.write(error: make_error, log_path: log_path)
    payload = JSON.parse(File.read(path))
    expect(payload["last_events"].length).to eq(3)
  end

  it "skips invalid JSON lines silently" do
    File.open(log_path, "w") do |f|
      f.puts "this is not json"
      f.puts JSON.generate(msg: "ok")
      f.puts "{ partial"
    end
    path = described_class.write(error: make_error, log_path: log_path)
    payload = JSON.parse(File.read(path))
    expect(payload["last_events"]).to eq([{ "msg" => "ok" }])
  end

  it "returns nil and warns instead of raising when writing fails" do
    allow(File).to receive(:open).and_raise(Errno::EACCES, "denied")

    output = StringIO.new
    orig = $stderr
    $stderr = output
    begin
      result = described_class.write(error: make_error, log_path: nil)
      expect(result).to be_nil
      expect(output.string).to include("[crash-report-failed]")
    ensure
      $stderr = orig
    end
  end

  it "writes the crash file with 0600 permissions" do
    path = described_class.write(error: make_error, log_path: nil)
    mode = File.stat(path).mode & 0o777
    expect(mode).to eq(0o600)
  end
end

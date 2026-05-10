# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"
require "stringio"
require "browserctl/commands/migrate"
require "browserctl/state/bundle"

RSpec.describe Browserctl::Commands::Migrate do
  let(:tmp_dir) { Dir.mktmpdir("browserctl-migrate-cli") }
  let(:out)     { StringIO.new }
  let(:err)     { StringIO.new }

  before { Browserctl::Migrations.reset! }
  after  do
    Browserctl::Migrations.reset!
    FileUtils.remove_entry(tmp_dir) if File.directory?(tmp_dir)
  end

  it "prints a 'nothing to do' notice on a current-version artifact" do
    path = File.join(tmp_dir, "rec.jsonl")
    File.write(path, "#{JSON.generate(cmd: '_meta', format_version: 1, recording: 'x')}\n")

    described_class.run([path], out: out, err: err)
    expect(out.string).to include("Detected: format=recording version=1")
    expect(out.string).to include("nothing to do")
  end

  it "exits with PROTOCOL_MISMATCH on a recording with an unsupported format_version" do
    path = File.join(tmp_dir, "rec.jsonl")
    File.write(path, "#{JSON.generate(cmd: '_meta', format_version: 99, recording: 'x')}\n")

    expect do
      described_class.run([path], out: out, err: err)
    end.to raise_error(SystemExit) { |e| expect(e.status).to eq(Browserctl::Error::ExitCodes::PROTOCOL_MISMATCH) }
    expect(err.string).to include("unsupported format_version=99")
  end

  it "exits with PROTOCOL_MISMATCH on an unknown extension" do
    path = File.join(tmp_dir, "mystery.xyz")
    File.write(path, "data")

    expect do
      described_class.run([path], out: out, err: err)
    end.to raise_error(SystemExit) { |e| expect(e.status).to eq(Browserctl::Error::ExitCodes::PROTOCOL_MISMATCH) }
    expect(err.string).to include("could not detect format")
  end

  it "exits with PROTOCOL_MISMATCH when no path reaches --to-version" do
    path = File.join(tmp_dir, "rec.jsonl")
    File.write(path, "#{JSON.generate(cmd: '_meta', format_version: 1, recording: 'x')}\n")

    expect do
      described_class.run([path, "--to-version", "99"], out: out, err: err)
    end.to raise_error(SystemExit) { |e| expect(e.status).to eq(Browserctl::Error::ExitCodes::PROTOCOL_MISMATCH) }
    expect(err.string).to include("no migration path")
  end

  it "prints a plan and skips writes under --dry-run" do
    path = File.join(tmp_dir, "rec.jsonl")
    original = "#{JSON.generate(cmd: '_meta', format_version: 1, recording: 'x')}\n"
    File.write(path, original)

    Browserctl::Migrations.register(format: :recording, from_version: 1, to_version: 2) do |path:, **|
      File.write(path, "TOUCHED")
    end

    described_class.run([path, "--dry-run"], out: out, err: err)
    expect(out.string).to include("Plan (1 step(s))")
    expect(out.string).to include("recording v1 -> v2")
    expect(File.read(path)).to eq(original)
  end

  it "applies a registered migration end-to-end" do
    path = File.join(tmp_dir, "rec.jsonl")
    File.write(path, "#{JSON.generate(cmd: '_meta', format_version: 1, recording: 'x')}\n")

    Browserctl::Migrations.register(format: :recording, from_version: 1, to_version: 2) do |path:, **|
      File.write(path, "#{JSON.generate(cmd: '_meta', format_version: 2, recording: 'x')}\n")
    end

    described_class.run([path], out: out, err: err)
    expect(out.string).to include("Applied 1 migration(s): 1 -> 2")
    expect(JSON.parse(File.read(path).lines.first)["format_version"]).to eq(2)
  end

  it "exits with GENERIC when the file does not exist" do
    expect do
      described_class.run([File.join(tmp_dir, "nope.bctl")], out: out, err: err)
    end.to raise_error(SystemExit) { |e| expect(e.status).to eq(Browserctl::Error::ExitCodes::GENERIC) }
  end
end

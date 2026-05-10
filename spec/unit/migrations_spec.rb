# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"
require "browserctl/migrations"
require "browserctl/state/bundle"

RSpec.describe Browserctl::Migrations do
  let(:tmp_dir) { Dir.mktmpdir("browserctl-migrations") }

  before { described_class.reset! }
  after  do
    described_class.reset!
    FileUtils.remove_entry(tmp_dir) if File.directory?(tmp_dir)
  end

  describe "default state" do
    it "ships with an empty registry" do
      expect(described_class.all).to eq([])
    end
  end

  describe ".register" do
    it "appends a Migration entry" do
      described_class.register(format: :bundle, from_version: 1, to_version: 2) { |**| nil }
      expect(described_class.all.size).to eq(1)
      expect(described_class.all.first).to have_attributes(format: :bundle, from_version: 1, to_version: 2)
    end

    it "rejects registration without an upgrade block" do
      expect { described_class.register(format: :bundle, from_version: 1, to_version: 2) }
        .to raise_error(ArgumentError, /upgrade block required/)
    end
  end

  describe ".find_path" do
    it "returns an empty array when from == to" do
      expect(described_class.find_path(format: :bundle, from: 1, to: 1)).to eq([])
    end

    it "chains two hops" do
      described_class.register(format: :bundle, from_version: 1, to_version: 2) { |**| nil }
      described_class.register(format: :bundle, from_version: 2, to_version: 3) { |**| nil }

      chain = described_class.find_path(format: :bundle, from: 1, to: 3)
      expect(chain.map(&:to_version)).to eq([2, 3])
    end

    it "returns nil when no path exists" do
      described_class.register(format: :bundle, from_version: 1, to_version: 2) { |**| nil }
      expect(described_class.find_path(format: :bundle, from: 1, to: 5)).to be_nil
    end

    it "ignores migrations from other formats" do
      described_class.register(format: :recording, from_version: 1, to_version: 2) { |**| nil }
      expect(described_class.find_path(format: :bundle, from: 1, to: 2)).to be_nil
    end
  end

  describe ".detect_format" do
    it "maps known extensions" do
      expect(described_class.detect_format("foo.bctl")).to eq(:bundle)
      expect(described_class.detect_format("bar.jsonl")).to eq(:recording)
      expect(described_class.detect_format("baz.rb")).to eq(:workflow)
    end

    it "returns nil for unknown extensions" do
      expect(described_class.detect_format("unknown.txt")).to be_nil
    end
  end

  describe ".detect_version" do
    it "reads the version from a recording log" do
      path = File.join(tmp_dir, "rec.jsonl")
      File.write(path, "#{JSON.generate(cmd: '_meta', format_version: 1, recording: 'x')}\n")
      expect(described_class.detect_version(path, :recording)).to eq(1)
    end

    it "reads the version from a bundle manifest" do
      path = File.join(tmp_dir, "state.bctl")
      blob = Browserctl::State::Bundle.encode(manifest: { origins: ["x"] }, payload: { "k" => "v" })
      File.binwrite(path, blob)
      expect(described_class.detect_version(path, :bundle)).to eq(1)
    end

    it "reads the version from a workflow comment" do
      path = File.join(tmp_dir, "wf.rb")
      File.write(path, "# frozen_string_literal: true\n# format_version: 1\n")
      expect(described_class.detect_version(path, :workflow)).to eq(1)
    end
  end

  describe ".run" do
    it "applies upgraders in order on a tmpfile" do
      path = File.join(tmp_dir, "rec.jsonl")
      File.write(path, "#{JSON.generate(cmd: '_meta', format_version: 1, recording: 'x')}\n")

      calls = []
      described_class.register(format: :recording, from_version: 1, to_version: 2) do |path:, **|
        calls << [1, 2, path]
        File.write(path, "#{JSON.generate(cmd: '_meta', format_version: 2, recording: 'x')}\n")
      end
      described_class.register(format: :recording, from_version: 2, to_version: 3) do |path:, **|
        calls << [2, 3, path]
        File.write(path, "#{JSON.generate(cmd: '_meta', format_version: 3, recording: 'x')}\n")
      end

      result = described_class.run(path)
      expect(result.format).to eq(:recording)
      expect(result.from).to eq(1)
      expect(result.to).to eq(3)
      expect(result.applied.map { |m| [m.from_version, m.to_version] }).to eq([[1, 2], [2, 3]])
      expect(calls.map { |c| c[0..1] }).to eq([[1, 2], [2, 3]])
      expect(JSON.parse(File.read(path).lines.first)["format_version"]).to eq(3)
    end

    it "is a no-op when no migrations are registered" do
      path = File.join(tmp_dir, "rec.jsonl")
      File.write(path, "#{JSON.generate(cmd: '_meta', format_version: 1, recording: 'x')}\n")

      result = described_class.run(path)
      expect(result.applied).to eq([])
      expect(result.from).to eq(1)
      expect(result.to).to eq(1)
    end

    it "raises ProtocolMismatch when no path reaches the target" do
      path = File.join(tmp_dir, "rec.jsonl")
      File.write(path, "#{JSON.generate(cmd: '_meta', format_version: 1, recording: 'x')}\n")

      expect { described_class.run(path, target_version: 99) }
        .to raise_error(Browserctl::ProtocolMismatch, /no migration path/)
    end

    it "raises ProtocolMismatch when format cannot be detected" do
      path = File.join(tmp_dir, "mystery.xyz")
      File.write(path, "data")
      expect { described_class.run(path) }
        .to raise_error(Browserctl::ProtocolMismatch, /could not detect format/)
    end
  end
end

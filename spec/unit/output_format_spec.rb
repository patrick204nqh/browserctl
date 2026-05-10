# frozen_string_literal: true

require "stringio"
require "browserctl/commands/output_format"

RSpec.describe Browserctl::Commands::OutputFormat do
  after { Browserctl::Commands::OutputFormat.reset! }

  describe ".from" do
    it "defaults to text when neither flag nor env is set" do
      fmt = described_class.from(nil, {})
      expect(fmt.mode).to eq("text")
      expect(fmt).to be_text
    end

    it "honours the explicit flag over the env var" do
      fmt = described_class.from("silent", { "BROWSERCTL_OUTPUT" => "json" })
      expect(fmt.mode).to eq("silent")
    end

    it "falls back to BROWSERCTL_OUTPUT when no flag is given" do
      fmt = described_class.from(nil, { "BROWSERCTL_OUTPUT" => "json" })
      expect(fmt.mode).to eq("json")
    end

    it "is case-insensitive and trims whitespace" do
      fmt = described_class.from(" JSON ", {})
      expect(fmt.mode).to eq("json")
    end

    it "raises InvalidFormat for unknown values" do
      expect { described_class.from("yaml", {}) }
        .to raise_error(described_class::InvalidFormat, /yaml/)
    end
  end

  describe ".extract!" do
    it "removes --output and its value from args, returning the value" do
      args = ["page", "list", "--output", "json", "--daemon", "d1"]
      expect(described_class.extract!(args)).to eq("json")
      expect(args).to eq(["page", "list", "--daemon", "d1"])
    end

    it "supports --output=value form" do
      args = ["--output=silent", "page", "list"]
      expect(described_class.extract!(args)).to eq("silent")
      expect(args).to eq(%w[page list])
    end

    it "returns nil and leaves args untouched when flag is absent" do
      args = %w[page list]
      expect(described_class.extract!(args)).to be_nil
      expect(args).to eq(%w[page list])
    end

    it "raises when the flag has no value" do
      args = ["page", "--output"]
      expect { described_class.extract!(args) }.to raise_error(described_class::InvalidFormat)
    end
  end

  describe Browserctl::Commands::OutputFormat::Formatter do
    let(:io) { StringIO.new }
    let(:payload) { { ok: true, items: [1, 2, 3] } }

    context "in text mode" do
      let(:fmt) { described_class.new("text") }

      it "prints the JSON payload when no text override is provided" do
        fmt.emit(payload, io: io)
        expect(io.string).to eq("#{payload.to_json}\n")
      end

      it "prints the text override when given" do
        fmt.emit(payload, "human readable", io: io)
        expect(io.string).to eq("human readable\n")
      end

      it "prints the block result when a block is given" do
        fmt.emit(payload, io: io) { "from block" }
        expect(io.string).to eq("from block\n")
      end
    end

    context "in json mode" do
      let(:fmt) { described_class.new("json") }

      it "prints the payload as JSON regardless of any text override" do
        fmt.emit(payload, "human readable", io: io)
        expect(io.string).to eq("#{payload.to_json}\n")
      end
    end

    context "in silent mode" do
      let(:fmt) { described_class.new("silent") }

      it "prints nothing on success" do
        fmt.emit(payload, "human readable", io: io)
        expect(io.string).to eq("")
      end

      it "does not evaluate the text block" do
        called = false
        fmt.emit(payload, io: io) do
          called = true
          "x"
        end
        expect(called).to be(false)
      end
    end
  end

  describe ".install!" do
    it "extracts the flag from args and updates the current formatter" do
      args = ["page", "list", "--output", "json"]
      fmt = described_class.install!(args, {})
      expect(fmt).to be_json
      expect(described_class.current).to be(fmt)
      expect(args).to eq(%w[page list])
    end

    it "uses the env var when no explicit flag is provided" do
      args = %w[page list]
      fmt = described_class.install!(args, { "BROWSERCTL_OUTPUT" => "silent" })
      expect(fmt).to be_silent
    end
  end
end

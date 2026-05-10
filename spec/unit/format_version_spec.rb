# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "browserctl/format_version"

RSpec.describe Browserctl::FormatVersion do
  describe ".stamp" do
    it "returns a canonical header line for a non-negative integer" do
      expect(described_class.stamp(version: 1)).to eq("version: 1\n")
      expect(described_class.stamp(version: 0)).to eq("version: 0\n")
      expect(described_class.stamp(version: 42)).to eq("version: 42\n")
    end

    it "rejects non-integer versions" do
      expect { described_class.stamp(version: "1") }.to raise_error(ArgumentError)
      expect { described_class.stamp(version: 1.0) }.to raise_error(ArgumentError)
    end

    it "rejects negative versions" do
      expect { described_class.stamp(version: -1) }.to raise_error(ArgumentError)
    end
  end

  describe ".parse" do
    it "parses a String body" do
      expect(described_class.parse("version: 3\nrest of file\n")).to eq(3)
    end

    it "parses an IO" do
      io = StringIO.new("version: 7\npayload\n")
      expect(described_class.parse(io)).to eq(7)
    end

    it "round-trips with .stamp" do
      [0, 1, 99, 1234].each do |v|
        expect(described_class.parse(described_class.stamp(version: v))).to eq(v)
      end
    end

    it "raises ProtocolMismatch on a missing header" do
      expect { described_class.parse("") }.to raise_error(Browserctl::ProtocolMismatch, /missing/)
    end

    it "raises ProtocolMismatch on a malformed header" do
      expect { described_class.parse("hello\n") }
        .to raise_error(Browserctl::ProtocolMismatch, /malformed/)
      expect { described_class.parse("version: abc\n") }
        .to raise_error(Browserctl::ProtocolMismatch, /malformed/)
      expect { described_class.parse("VERSION: 1\n") }
        .to raise_error(Browserctl::ProtocolMismatch, /malformed/)
    end

    it "raises with the canonical PROTOCOL_MISMATCH code" do
      described_class.parse("nope\n")
    rescue Browserctl::ProtocolMismatch => e
      expect(e.code).to eq("PROTOCOL_MISMATCH")
    end
  end
end

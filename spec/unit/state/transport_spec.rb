# frozen_string_literal: true

require "tmpdir"
require "browserctl/state"

RSpec.describe Browserctl::State::Transport do
  describe ".for" do
    it "selects the file transport for bare paths" do
      transport, parsed = described_class.for("/tmp/example.bctl")
      expect(transport).to be_a(Browserctl::State::Transports::File)
      expect(parsed.path).to eq("/tmp/example.bctl")
    end

    it "selects the file transport for file:// URIs" do
      transport, = described_class.for("file:///tmp/x.bctl")
      expect(transport).to be_a(Browserctl::State::Transports::File)
    end

    it "selects the s3 transport for s3:// URIs" do
      transport, = described_class.for("s3://bucket/key.bctl")
      expect(transport).to be_a(Browserctl::State::Transports::S3)
    rescue Browserctl::State::Transport::TransportError => e
      # accept "not available" on machines without aws CLI
      expect(e.message).to match(/not available/)
    end

    it "selects the op transport for op:// URIs" do
      transport, = described_class.for("op://Vault/Item")
      expect(transport).to be_a(Browserctl::State::Transports::OnePassword)
    rescue Browserctl::State::Transport::TransportError => e
      expect(e.message).to match(/not available/)
    end

    it "raises for unknown schemes" do
      expect { described_class.for("ftp://nope") }.to raise_error(described_class::TransportError)
    end
  end

  describe "FileTransport round-trip" do
    it "writes and reads back binary blobs verbatim" do
      Dir.mktmpdir do |tmp|
        path = File.join(tmp, "x.bctl")
        blob = (0..255).map(&:chr).join.b

        transport, parsed = described_class.for(path)
        transport.write(parsed, blob)
        expect(transport.read(parsed)).to eq(blob)
        expect(File.stat(path).mode & 0o777).to eq(0o600)
      end
    end

    it "raises a TransportError when reading a missing file" do
      transport, parsed = described_class.for("/tmp/this-does-not-exist-#{rand(10**9)}.bctl")
      expect { transport.read(parsed) }.to raise_error(described_class::TransportError)
    end
  end
end

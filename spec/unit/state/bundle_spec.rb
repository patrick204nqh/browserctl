# frozen_string_literal: true

require "spec_helper"
require "browserctl/state/bundle"

RSpec.describe Browserctl::State::Bundle do
  let(:manifest) do
    {
      version: 1,
      flow: "github_login",
      flow_version: "1.0.0",
      origins: ["github.com", "api.github.com"],
      created_at: 1_700_000_000
    }
  end

  let(:payload) do
    {
      "cookies" => [{ "name" => "sess", "value" => "abc", "domain" => ".github.com" }],
      "local_storage" => { "user" => "patrick" },
      "session_storage" => {}
    }
  end

  describe "plaintext bundles" do
    it "round-trips manifest and payload" do
      blob = described_class.encode(manifest: manifest, payload: payload)
      out  = described_class.decode(blob)

      expect(out[:manifest]).to eq(manifest.merge(format_version: described_class::BUNDLE_FORMAT_VERSION))
      expect(out[:payload]).to eq(payload)
      expect(out[:encrypted]).to be false
    end

    it "starts with the BCTL magic" do
      blob = described_class.encode(manifest: manifest, payload: payload)
      expect(blob.byteslice(0, 5)).to eq("BCTL\x00".b)
    end

    it "raises TamperError when any byte of the body is modified" do
      blob = described_class.encode(manifest: manifest, payload: payload)
      offset = blob.bytesize - described_class::FOOTER_SIZE - 5
      blob.setbyte(offset, blob.getbyte(offset) ^ 0xFF)

      expect { described_class.decode(blob) }
        .to raise_error(described_class::TamperError, /corrupted/) do |e|
        expect(e.code).to eq("bundle_tampered")
      end
    end

    it "raises TamperError when the footer is mutated" do
      blob = described_class.encode(manifest: manifest, payload: payload)
      offset = blob.bytesize - 1
      blob.setbyte(offset, blob.getbyte(offset) ^ 0xFF)

      expect { described_class.decode(blob) }.to raise_error(described_class::TamperError)
    end
  end

  describe "encrypted bundles" do
    let(:passphrase) { "correct horse battery staple" }

    it "round-trips with the right passphrase" do
      blob = described_class.encode(manifest: manifest, payload: payload, passphrase: passphrase)
      out  = described_class.decode(blob, passphrase: passphrase)

      expect(out[:manifest]).to eq(manifest.merge(format_version: described_class::BUNDLE_FORMAT_VERSION))
      expect(out[:payload]).to eq(payload)
      expect(out[:encrypted]).to be true
    end

    it "produces different ciphertext on each encode (random salt + nonce)" do
      a = described_class.encode(manifest: manifest, payload: payload, passphrase: passphrase)
      b = described_class.encode(manifest: manifest, payload: payload, passphrase: passphrase)

      expect(a).not_to eq(b)
    end

    it "raises PassphraseError on a wrong passphrase" do
      blob = described_class.encode(manifest: manifest, payload: payload, passphrase: passphrase)

      expect { described_class.decode(blob, passphrase: "wrong") }
        .to raise_error(described_class::PassphraseError, /wrong passphrase/) do |e|
        expect(e.code).to eq("bundle_passphrase")
      end
    end

    it "raises PassphraseError when no passphrase given for an encrypted bundle" do
      blob = described_class.encode(manifest: manifest, payload: payload, passphrase: passphrase)

      expect { described_class.decode(blob) }
        .to raise_error(described_class::PassphraseError, /requires a passphrase/)
    end

    it "raises PassphraseError when ciphertext is mutated" do
      blob = described_class.encode(manifest: manifest, payload: payload, passphrase: passphrase)
      # Flip a byte deep in the encrypted payload
      mid = blob.bytesize / 2
      blob.setbyte(mid, blob.getbyte(mid) ^ 0xFF)

      expect { described_class.decode(blob, passphrase: passphrase) }
        .to raise_error(described_class::PassphraseError)
    end

    it "leaves the manifest readable without a passphrase" do
      blob = described_class.encode(manifest: manifest, payload: payload, passphrase: passphrase)

      m = described_class.peek_manifest(blob)

      expect(m).to eq(manifest.merge(format_version: described_class::BUNDLE_FORMAT_VERSION))
    end
  end

  describe ".peek_manifest" do
    it "reads the manifest from a plaintext bundle" do
      blob = described_class.encode(manifest: manifest, payload: payload)
      expect(described_class.peek_manifest(blob))
        .to eq(manifest.merge(format_version: described_class::BUNDLE_FORMAT_VERSION))
    end

    it "raises BundleError on a non-bundle blob" do
      expect { described_class.peek_manifest("not a bundle") }
        .to raise_error(described_class::BundleError, /bad magic|too small/)
    end

    it "raises BundleError on truncated input" do
      blob = described_class.encode(manifest: manifest, payload: payload)
      truncated = blob.byteslice(0, blob.bytesize - 60)

      expect { described_class.decode(truncated) }
        .to raise_error(described_class::BundleError)
    end
  end

  describe "version handling" do
    it "rejects unknown versions" do
      blob = described_class.encode(manifest: manifest, payload: payload)
      blob.setbyte(5, 99) # version byte

      expect { described_class.decode(blob) }
        .to raise_error(described_class::BundleError, /unsupported bundle version/)
    end
  end

  describe "manifest format_version" do
    it "stamps format_version: 1 as the first manifest key on encode" do
      blob = described_class.encode(manifest: manifest, payload: payload)
      m = described_class.peek_manifest(blob)

      expect(m[:format_version]).to eq(1)
      expect(m.keys.first).to eq(:format_version)
    end

    it "round-trips with format_version: 1" do
      blob = described_class.encode(manifest: manifest, payload: payload)
      out  = described_class.decode(blob)

      expect(out[:manifest][:format_version]).to eq(described_class::BUNDLE_FORMAT_VERSION)
    end

    it "raises ProtocolMismatch with PROTOCOL_MISMATCH code when format_version is unknown" do
      blob = described_class.encode(
        manifest: manifest.merge(format_version: 999),
        payload: payload
      )

      expect { described_class.decode(blob) }
        .to raise_error(Browserctl::ProtocolMismatch, /999/) do |e|
          expect(e.code).to eq(Browserctl::Error::Codes::PROTOCOL_MISMATCH)
          expect(e.message).to match(/format_version/)
        end
    end

    it "raises ProtocolMismatch when format_version is missing (legacy bundle)" do
      # Hand-build a blob whose manifest has no format_version, simulating a
      # pre-WS-1 bundle on disk.
      legacy_manifest = manifest.except(:format_version)
      manifest_bytes = JSON.generate(legacy_manifest).b
      payload_bytes  = JSON.generate(payload).b
      header = described_class::MAGIC + [described_class::VERSION, 0, 0].pack("CCC")
      body = header +
             [manifest_bytes.bytesize].pack("N") + manifest_bytes +
             [payload_bytes.bytesize].pack("N") + payload_bytes
      footer = OpenSSL::Digest.digest("SHA256", body)
      blob = body + footer

      expect { described_class.decode(blob) }
        .to raise_error(Browserctl::ProtocolMismatch, /missing format_version/) do |e|
          expect(e.code).to eq(Browserctl::Error::Codes::PROTOCOL_MISMATCH)
        end
    end

    it "raises ProtocolMismatch from peek_manifest on an unknown format_version" do
      blob = described_class.encode(
        manifest: manifest.merge(format_version: 999),
        payload: payload
      )

      expect { described_class.peek_manifest(blob) }
        .to raise_error(Browserctl::ProtocolMismatch)
    end
  end

  describe "round-trip across state combinations" do
    # Each entry exercises a distinct payload shape the codec must carry
    # without loss, in both plaintext and encrypted modes.
    payload_variants = {
      "empty payload" => {},
      "cookies only" => {
        "cookies" => [
          { "name" => "a", "value" => "1", "domain" => ".example.com" },
          { "name" => "b", "value" => "2", "domain" => ".example.com" }
        ]
      },
      "local_storage only" => {
        "local_storage" => { "k1" => "v1", "k2" => "v2" }
      },
      "session_storage only" => {
        "session_storage" => { "session" => "xyz" }
      },
      "indexeddb-shaped" => {
        "indexeddb" => { "db1" => { "store1" => [{ "id" => 1, "data" => "blob" }] } }
      },
      "all storage types together" => {
        "cookies" => [{ "name" => "c", "value" => "v", "domain" => ".x.com" }],
        "local_storage" => { "k" => "v" },
        "session_storage" => { "k" => "v" },
        "indexeddb" => { "db" => { "store" => [] } }
      },
      "unicode + control chars" => {
        "local_storage" => { "emoji" => "shrug ¯\\_(ツ)_/¯", "newline" => "a\nb\tc" }
      },
      "deeply nested" => {
        "nested" => { "a" => { "b" => { "c" => { "d" => [1, 2, [3, 4, { "e" => "f" }]] } } } }
      },
      "large payload (~64KB)" => {
        "local_storage" => { "blob" => ("x" * 64_000) }
      }
    }

    manifest_variants = {
      "minimal manifest" => { version: 1, flow: "f", flow_version: "1", origins: [] },
      "manifest with many origins" => {
        version: 1, flow: "f", flow_version: "1",
        origins: Array.new(50) { |i| "host-#{i}.example.com" }
      }
    }

    payload_variants.each do |label, p|
      context "with payload: #{label}" do
        it "round-trips plaintext" do
          blob = described_class.encode(manifest: manifest, payload: p)
          out = described_class.decode(blob)
          expect(out[:payload]).to eq(p)
          expect(out[:encrypted]).to be false
          expect(out[:manifest][:format_version]).to eq(described_class::BUNDLE_FORMAT_VERSION)
        end

        it "round-trips encrypted" do
          blob = described_class.encode(manifest: manifest, payload: p, passphrase: "pw")
          out = described_class.decode(blob, passphrase: "pw")
          expect(out[:payload]).to eq(p)
          expect(out[:encrypted]).to be true
        end
      end
    end

    manifest_variants.each do |label, m|
      it "round-trips with manifest: #{label}" do
        blob = described_class.encode(manifest: m, payload: { "k" => "v" })
        out = described_class.decode(blob)
        expect(out[:manifest]).to eq(m.merge(format_version: described_class::BUNDLE_FORMAT_VERSION))
      end
    end
  end

  describe "additional failure modes" do
    it "raises BundleError on decode of a non-bundle blob (bad magic)" do
      junk = ("X" * 200).b
      expect { described_class.decode(junk) }
        .to raise_error(described_class::BundleError, /bad magic|too small/)
    end

    it "raises BundleError on a blob shorter than the minimum header" do
      expect { described_class.decode("BCTL".b) }
        .to raise_error(described_class::BundleError, /too small/)
    end

    it "raises PassphraseError when the salt inside an encrypted payload is mutated" do
      blob = described_class.encode(manifest: manifest, payload: payload, passphrase: "pw")
      # Salt sits at the start of the encrypted payload, which begins right
      # after HEADER_SIZE + LEN_SIZE + manifest_len + LEN_SIZE.
      header  = described_class::HEADER_SIZE
      manlen  = blob.byteslice(header, 4).unpack1("N")
      salt_at = header + 4 + manlen + 4
      blob.setbyte(salt_at, blob.getbyte(salt_at) ^ 0xFF)

      expect { described_class.decode(blob, passphrase: "pw") }
        .to raise_error(described_class::PassphraseError)
    end

    it "raises PassphraseError when the GCM auth tag is mutated" do
      blob = described_class.encode(manifest: manifest, payload: payload, passphrase: "pw")
      # Tag is the last 16 bytes before the 32-byte HMAC footer.
      tag_at = blob.bytesize - described_class::FOOTER_SIZE - 1
      blob.setbyte(tag_at, blob.getbyte(tag_at) ^ 0xFF)

      expect { described_class.decode(blob, passphrase: "pw") }
        .to raise_error(described_class::PassphraseError)
    end

    it "raises BundleError when truncated mid-payload" do
      blob = described_class.encode(manifest: manifest, payload: payload)
      truncated = blob.byteslice(0, blob.bytesize - 80)
      expect { described_class.decode(truncated) }
        .to raise_error(described_class::BundleError)
    end

    it "carries a code on every BundleError subclass" do
      blob = described_class.encode(manifest: manifest, payload: payload)
      blob.setbyte(blob.bytesize - 1, blob.getbyte(blob.bytesize - 1) ^ 0xFF)
      begin
        described_class.decode(blob)
      rescue described_class::BundleError => e
        expect(e.code).to eq("bundle_tampered")
      end
    end
  end
end

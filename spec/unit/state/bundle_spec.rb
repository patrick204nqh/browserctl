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

      expect(out[:manifest]).to eq(manifest)
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

      expect(out[:manifest]).to eq(manifest)
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

      expect(m).to eq(manifest)
    end
  end

  describe ".peek_manifest" do
    it "reads the manifest from a plaintext bundle" do
      blob = described_class.encode(manifest: manifest, payload: payload)
      expect(described_class.peek_manifest(blob)).to eq(manifest)
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
end

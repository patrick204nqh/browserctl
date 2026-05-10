# frozen_string_literal: true

require "spec_helper"
require "browserctl/encryption_service"

RSpec.describe Browserctl::EncryptionService do
  let(:passphrase) { "correct horse battery staple" }
  let(:salt) { described_class.random_salt }
  let(:enc_key) { described_class.derive_keys(passphrase, salt).first }

  describe ".derive_keys" do
    it "returns an [enc_key, hmac_key] pair of KEY_SIZE bytes each" do
      enc, hmac = described_class.derive_keys(passphrase, salt)
      expect(enc.bytesize).to eq(described_class::KEY_SIZE)
      expect(hmac.bytesize).to eq(described_class::KEY_SIZE)
      expect(enc).not_to eq(hmac)
    end

    it "is deterministic for the same passphrase and salt" do
      keys_a = described_class.derive_keys(passphrase, salt)
      keys_b = described_class.derive_keys(passphrase, salt)
      expect(keys_a).to eq(keys_b)
    end

    it "diverges when the salt changes" do
      other = described_class.random_salt
      expect(described_class.derive_keys(passphrase, salt))
        .not_to eq(described_class.derive_keys(passphrase, other))
    end

    it "diverges when the passphrase changes" do
      expect(described_class.derive_keys(passphrase, salt))
        .not_to eq(described_class.derive_keys("different", salt))
    end

    it "coerces non-string passphrases via to_s" do
      expect { described_class.derive_keys(:symbol_passphrase, salt) }.not_to raise_error
    end
  end

  describe ".encrypt / .decrypt" do
    let(:plaintext) { "hello, browserctl" }

    it "round-trips plaintext" do
      blob = described_class.encrypt(plaintext, enc_key)
      expect(described_class.decrypt(blob, enc_key)).to eq(plaintext)
    end

    it "produces a fresh nonce each call (so output differs)" do
      a = described_class.encrypt(plaintext, enc_key)
      b = described_class.encrypt(plaintext, enc_key)
      expect(a).not_to eq(b)
    end

    it "lays out the ciphertext as nonce || ciphertext || tag" do
      blob = described_class.encrypt(plaintext, enc_key)
      expected_min = described_class::NONCE_SIZE + described_class::TAG_SIZE
      expect(blob.bytesize).to be > expected_min
    end

    it "raises DecryptionError on a wrong key" do
      blob = described_class.encrypt(plaintext, enc_key)
      wrong_key = described_class.derive_keys("wrong", salt).first
      expect { described_class.decrypt(blob, wrong_key) }
        .to raise_error(described_class::DecryptionError)
    end

    it "raises DecryptionError when the ciphertext is tampered" do
      blob = described_class.encrypt(plaintext, enc_key)
      tampered = blob.dup
      # Flip a byte in the ciphertext region (after the nonce, before the tag).
      idx = described_class::NONCE_SIZE
      tampered.setbyte(idx, tampered.getbyte(idx) ^ 0x01)
      expect { described_class.decrypt(tampered, enc_key) }
        .to raise_error(described_class::DecryptionError)
    end

    it "raises DecryptionError when the auth tag is tampered" do
      blob = described_class.encrypt(plaintext, enc_key)
      tampered = blob.dup
      tampered.setbyte(-1, tampered.getbyte(-1) ^ 0xFF)
      expect { described_class.decrypt(tampered, enc_key) }
        .to raise_error(described_class::DecryptionError)
    end
  end

  describe ".random_salt / .random_nonce" do
    it "returns SALT_SIZE bytes" do
      expect(described_class.random_salt.bytesize).to eq(described_class::SALT_SIZE)
    end

    it "returns NONCE_SIZE bytes" do
      expect(described_class.random_nonce.bytesize).to eq(described_class::NONCE_SIZE)
    end

    it "produces fresh values on each call" do
      expect(described_class.random_salt).not_to eq(described_class.random_salt)
      expect(described_class.random_nonce).not_to eq(described_class.random_nonce)
    end
  end

  describe "constants" do
    it "exposes the bundle-wire-format sizes" do
      expect(described_class::SALT_SIZE).to eq(16)
      expect(described_class::NONCE_SIZE).to eq(12)
      expect(described_class::TAG_SIZE).to eq(16)
      expect(described_class::KEY_SIZE).to eq(32)
      expect(described_class::PBKDF2_ITERS).to eq(200_000)
    end
  end
end

# frozen_string_literal: true

require "openssl"
require "securerandom"

module Browserctl
  # Cryptographic primitives for browserctl-managed payloads.
  #
  # Raised when decryption fails (tampered ciphertext or wrong key). Callers
  # should catch this rather than `OpenSSL::Cipher::CipherError` so they
  # don't have to take a direct dependency on the underlying cipher library.
  #
  # Owns AES-256-GCM cipher setup and PBKDF2 key derivation so callers like
  # `State::Bundle` don't reach into `OpenSSL::Cipher` directly. The contract
  # is intentionally narrow:
  #
  #   * `derive_keys(passphrase, salt)` returns a `[enc_key, hmac_key]` pair
  #     derived via PBKDF2-HMAC-SHA256 with `PBKDF2_ITERS` iterations and a
  #     64-byte output split in half. The first half is the AES-256-GCM key,
  #     the second is the HMAC-SHA-256 key for the bundle footer.
  #   * `encrypt(plaintext, key)` returns `nonce || ciphertext || tag`.
  #   * `decrypt(blob, key)` reverses it; raises `OpenSSL::Cipher::CipherError`
  #     on tampered blobs / wrong key.
  #   * `random_salt` / `random_nonce` are exposed so callers can keep bundle
  #     wire-format assembly in one place without re-deriving sizes.
  #
  # The constants here are duplicated in `State::Bundle` only as named
  # references to the wire format positions; the source of truth lives here.
  module EncryptionService
    class DecryptionError < StandardError; end

    SALT_SIZE    = 16
    NONCE_SIZE   = 12
    TAG_SIZE     = 16
    KEY_SIZE     = 32
    PBKDF2_ITERS = 200_000
    DIGEST       = "SHA256"
    CIPHER       = "aes-256-gcm"

    module_function

    # Returns `[enc_key, hmac_key]`, each `KEY_SIZE` bytes.
    def derive_keys(passphrase, salt)
      material = OpenSSL::PKCS5.pbkdf2_hmac(passphrase.to_s, salt, PBKDF2_ITERS, KEY_SIZE * 2, DIGEST)
      [material.byteslice(0, KEY_SIZE), material.byteslice(KEY_SIZE, KEY_SIZE)]
    end

    # AES-256-GCM. Returns `nonce || ciphertext || tag`.
    def encrypt(plaintext, key)
      cipher = OpenSSL::Cipher.new(CIPHER)
      cipher.encrypt
      cipher.key = key
      nonce = SecureRandom.bytes(NONCE_SIZE)
      cipher.iv = nonce
      ct = cipher.update(plaintext) + cipher.final
      nonce + ct + cipher.auth_tag
    end

    # Inverse of `encrypt`. Raises `DecryptionError` on tampered ciphertext
    # or wrong key so callers don't need to reach into `OpenSSL::Cipher`.
    def decrypt(blob, key)
      nonce      = blob.byteslice(0, NONCE_SIZE)
      tag        = blob.byteslice(-TAG_SIZE, TAG_SIZE)
      ciphertext = blob.byteslice(NONCE_SIZE, blob.bytesize - NONCE_SIZE - TAG_SIZE)

      cipher = OpenSSL::Cipher.new(CIPHER)
      cipher.decrypt
      cipher.key      = key
      cipher.iv       = nonce
      cipher.auth_tag = tag
      cipher.update(ciphertext) + cipher.final
    rescue OpenSSL::Cipher::CipherError => e
      raise DecryptionError, e.message
    end

    def random_salt
      SecureRandom.bytes(SALT_SIZE)
    end

    def random_nonce
      SecureRandom.bytes(NONCE_SIZE)
    end
  end
end

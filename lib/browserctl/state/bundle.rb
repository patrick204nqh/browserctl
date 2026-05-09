# frozen_string_literal: true

require "json"
require "openssl"
require "securerandom"
require_relative "../errors"

module Browserctl
  module State
    # Single-file portable codec for browserctl session state — the .bctl
    # bundle. Wraps a plaintext manifest (origins, flow binding, timestamps)
    # alongside a payload of cookies + storage. The manifest is always
    # readable without a passphrase (so `state info` can show origins and
    # expiry); the payload is optionally encrypted.
    #
    # Wire format (big-endian):
    #
    #   magic:        "BCTL\x00"           5 bytes
    #   version:      0x01                 1 byte
    #   flags:        bit 0 = encrypted    1 byte
    #   reserved:     0x00                 1 byte
    #   manifest_len:                      4 bytes
    #   manifest:     JSON                 manifest_len bytes (always plaintext)
    #   payload_len:                       4 bytes
    #   payload:      see below            payload_len bytes
    #   footer:       32 bytes
    #
    # When flags & 0x01 is unset:
    #   payload  = JSON bytes (plaintext)
    #   footer   = SHA-256 over magic..payload (corruption detection)
    #
    # When flags & 0x01 is set:
    #   payload  = salt(16) || nonce(12) || ciphertext || tag(16)
    #   footer   = HMAC-SHA-256(hmac_key, magic..payload)
    #   salt drives PBKDF2(passphrase, salt, 200_000, SHA-256, 64-byte output);
    #   first 32 bytes are the AES-256-GCM encryption key, last 32 bytes are
    #   the HMAC-SHA-256 key.
    #
    # Reuses the same AES-256-GCM primitive as v0.8 session encryption
    # (lib/browserctl/session.rb). The two will share a Crypto module in a
    # follow-up; duplicated here to keep this PR focused.
    class Bundle
      MAGIC          = "BCTL\x00".b.freeze
      VERSION        = 1
      FLAG_ENCRYPTED = 0x01
      HEADER_SIZE    = MAGIC.bytesize + 3 # version + flags + reserved
      LEN_SIZE       = 4
      FOOTER_SIZE    = 32
      SALT_SIZE      = 16
      NONCE_SIZE     = 12
      TAG_SIZE       = 16
      PBKDF2_ITERS   = 200_000

      class BundleError      < Browserctl::Error; def self.default_code = "bundle_error"      end
      class TamperError      < BundleError;       def self.default_code = "bundle_tampered"   end
      class PassphraseError  < BundleError;       def self.default_code = "bundle_passphrase" end

      # Encodes manifest + payload into a single binary blob.
      #
      # @param manifest [Hash] plaintext manifest (always readable)
      # @param payload  [Hash] cookies/storage; encrypted when passphrase given
      # @param passphrase [String, nil] when given, payload is encrypted and
      #   the footer is an HMAC. When nil, payload is plaintext and the
      #   footer is a SHA-256 digest.
      def self.encode(manifest:, payload:, passphrase: nil)
        manifest_bytes = JSON.generate(manifest).b
        payload_json   = JSON.generate(payload).b
        flags          = 0
        hmac_key       = nil

        if passphrase
          salt = SecureRandom.bytes(SALT_SIZE)
          enc_key, hmac_key = derive_keys(passphrase, salt)
          payload_bytes = salt + aes_gcm_encrypt(payload_json, enc_key)
          flags |= FLAG_ENCRYPTED
        else
          payload_bytes = payload_json
        end

        body = build_body(flags, manifest_bytes, payload_bytes)
        body + footer_for(body, hmac_key)
      end

      # Decodes a blob, verifying the footer and decrypting payload when
      # encrypted. Raises TamperError on digest/HMAC mismatch and
      # PassphraseError when an encrypted bundle is decoded without a
      # passphrase or with the wrong one.
      def self.decode(blob, passphrase: nil)
        magic, version, flags = read_header!(blob)
        raise BundleError, "unsupported bundle version #{version}" unless version == VERSION

        manifest_bytes, payload_bytes, footer = read_sections!(blob)
        body = blob.byteslice(0, blob.bytesize - FOOTER_SIZE)

        encrypted = flags.anybits?(FLAG_ENCRYPTED)
        verify_footer!(body, footer, encrypted: encrypted, passphrase: passphrase)

        manifest = JSON.parse(manifest_bytes, symbolize_names: true)
        payload  = decode_payload(payload_bytes, encrypted: encrypted, passphrase: passphrase)

        { manifest: manifest, payload: payload, magic: magic, version: version, encrypted: encrypted }
      end

      # Reads the manifest without verifying the footer or decrypting the
      # payload. Use for `state info` and similar read-only queries.
      def self.peek_manifest(blob)
        _, version, = read_header!(blob)
        raise BundleError, "unsupported bundle version #{version}" unless version == VERSION

        manifest_bytes, = read_sections!(blob)
        JSON.parse(manifest_bytes, symbolize_names: true)
      end

      def self.build_body(flags, manifest_bytes, payload_bytes)
        header = MAGIC + [VERSION, flags, 0].pack("CCC")
        header +
          [manifest_bytes.bytesize].pack("N") + manifest_bytes +
          [payload_bytes.bytesize].pack("N") + payload_bytes
      end
      private_class_method :build_body

      def self.footer_for(body, hmac_key)
        if hmac_key
          OpenSSL::HMAC.digest("SHA256", hmac_key, body)
        else
          OpenSSL::Digest.digest("SHA256", body)
        end
      end
      private_class_method :footer_for

      def self.read_header!(blob)
        raise BundleError, "blob too small for header" if blob.bytesize < HEADER_SIZE + (2 * LEN_SIZE) + FOOTER_SIZE

        magic = blob.byteslice(0, MAGIC.bytesize)
        raise BundleError, "bad magic — not a .bctl bundle" unless magic == MAGIC

        version, flags, _reserved = blob.byteslice(MAGIC.bytesize, 3).unpack("CCC")
        [magic, version, flags]
      end
      private_class_method :read_header!

      def self.read_sections!(blob)
        cursor          = HEADER_SIZE
        manifest_len    = blob.byteslice(cursor, LEN_SIZE).unpack1("N")
        cursor         += LEN_SIZE
        manifest_bytes  = blob.byteslice(cursor, manifest_len)
        cursor         += manifest_len
        payload_len     = blob.byteslice(cursor, LEN_SIZE).unpack1("N")
        cursor         += LEN_SIZE
        payload_bytes   = blob.byteslice(cursor, payload_len)
        cursor         += payload_len
        footer          = blob.byteslice(cursor, FOOTER_SIZE)

        unless manifest_bytes && payload_bytes && footer && footer.bytesize == FOOTER_SIZE
          raise BundleError, "truncated bundle"
        end

        [manifest_bytes, payload_bytes, footer]
      end
      private_class_method :read_sections!

      def self.verify_footer!(body, footer, encrypted:, passphrase:)
        if encrypted
          raise PassphraseError, "encrypted bundle requires a passphrase" unless passphrase

          # We need the HMAC key, which depends on the salt embedded in the
          # payload. Pull the salt from the payload bytes inside `body`.
          salt = extract_salt!(body)
          _, hmac_key = derive_keys(passphrase, salt)
          expected = OpenSSL::HMAC.digest("SHA256", hmac_key, body)
          raise PassphraseError, "wrong passphrase or tampered bundle" unless secure_eq?(footer, expected)
        else
          expected = OpenSSL::Digest.digest("SHA256", body)
          raise TamperError, "bundle digest mismatch — file is corrupted or modified" unless secure_eq?(footer,
                                                                                                        expected)
        end
      end
      private_class_method :verify_footer!

      def self.extract_salt!(body)
        cursor          = HEADER_SIZE
        manifest_len    = body.byteslice(cursor, LEN_SIZE).unpack1("N")
        cursor         += LEN_SIZE + manifest_len + LEN_SIZE
        body.byteslice(cursor, SALT_SIZE) or raise BundleError, "encrypted payload missing salt"
      end
      private_class_method :extract_salt!

      def self.decode_payload(bytes, encrypted:, passphrase:)
        if encrypted
          salt       = bytes.byteslice(0, SALT_SIZE)
          ciphertext = bytes.byteslice(SALT_SIZE, bytes.bytesize - SALT_SIZE)
          enc_key, = derive_keys(passphrase, salt)
          plaintext  = aes_gcm_decrypt(ciphertext, enc_key)
          JSON.parse(plaintext)
        else
          JSON.parse(bytes)
        end
      rescue OpenSSL::Cipher::CipherError
        raise PassphraseError, "wrong passphrase — payload could not be decrypted"
      end
      private_class_method :decode_payload

      def self.derive_keys(passphrase, salt)
        material = OpenSSL::PKCS5.pbkdf2_hmac(passphrase.to_s, salt, PBKDF2_ITERS, 64, "SHA256")
        [material.byteslice(0, 32), material.byteslice(32, 32)]
      end
      private_class_method :derive_keys

      def self.aes_gcm_encrypt(plaintext, key)
        cipher = OpenSSL::Cipher.new("aes-256-gcm")
        cipher.encrypt
        cipher.key = key
        nonce = SecureRandom.bytes(NONCE_SIZE)
        cipher.iv = nonce
        ct = cipher.update(plaintext) + cipher.final
        nonce + ct + cipher.auth_tag
      end
      private_class_method :aes_gcm_encrypt

      def self.aes_gcm_decrypt(blob, key)
        nonce      = blob.byteslice(0, NONCE_SIZE)
        tag        = blob.byteslice(-TAG_SIZE, TAG_SIZE)
        ciphertext = blob.byteslice(NONCE_SIZE, blob.bytesize - NONCE_SIZE - TAG_SIZE)

        cipher = OpenSSL::Cipher.new("aes-256-gcm")
        cipher.decrypt
        cipher.key      = key
        cipher.iv       = nonce
        cipher.auth_tag = tag
        cipher.update(ciphertext) + cipher.final
      end
      private_class_method :aes_gcm_decrypt

      def self.secure_eq?(actual, expected)
        return false if actual.bytesize != expected.bytesize

        OpenSSL.fixed_length_secure_compare(actual, expected)
      end
      private_class_method :secure_eq?
    end
  end
end

# frozen_string_literal: true

require "fileutils"
require "json"
require "openssl"
require "securerandom"
require "open3"
require_relative "constants"

module Browserctl
  class Session
    BASE_DIR = File.join(BROWSERCTL_DIR, "sessions")

    SAFE_NAME = /\A[a-zA-Z0-9_-]{1,64}\z/

    SENSITIVE_FILES = %w[cookies.json local_storage.json session_storage.json].freeze

    def self.path(name)    = File.join(BASE_DIR, name)
    def self.exist?(name)  = Dir.exist?(path(name))

    def self.delete(name)
      validate_name!(name)
      FileUtils.rm_rf(path(name))
    end

    def self.all
      Dir[File.join(BASE_DIR, "*/metadata.json")].filter_map { |f| load_meta(f) }
    end

    def self.save(session_name, metadata:, cookies:, local_storage:, session_storage:, encrypt: false) # rubocop:disable Metrics/ParameterLists
      validate_name!(session_name)
      key, metadata = prepare_encryption(session_name, metadata, encrypt)
      dir = path(session_name)
      FileUtils.mkdir_p(dir)
      write_json(File.join(dir, "metadata.json"), metadata)
      write_session_files(dir, cookies, local_storage, session_storage, key)
    end

    def self.prepare_encryption(session_name, metadata, encrypt)
      return [nil, metadata] unless encrypt

      unless keychain_available?
        raise Browserctl::Error,
              "session encryption requires macOS Keychain (darwin only)\n  " \
              "For Linux/CI, omit --encrypt and rely on 0o600 file permissions,\n  " \
              "or use BROWSERCTL_EXPORT_PASSPHRASE with session export --encrypt for portable archives."
      end

      key = SecureRandom.bytes(32)
      keychain_store(session_name, key)
      [key, metadata.merge(encrypted: true)]
    end
    private_class_method :prepare_encryption

    def self.write_session_files(dir, cookies, local_storage, session_storage, key)
      if key
        write_encrypted_secret(File.join(dir, "cookies.json.enc"), cookies, key)
        write_encrypted_secret(File.join(dir, "local_storage.json.enc"), local_storage, key)
        unless session_storage.empty?
          write_encrypted_secret(File.join(dir, "session_storage.json.enc"), session_storage,
                                 key)
        end
      else
        write_secret(File.join(dir, "cookies.json"), cookies)
        write_secret(File.join(dir, "local_storage.json"), local_storage)
        write_secret(File.join(dir, "session_storage.json"), session_storage) unless session_storage.empty?
      end
    end
    private_class_method :write_session_files

    def self.load(session_name)
      validate_name!(session_name)
      dir = path(session_name)
      raise "session '#{session_name}' not found" unless Dir.exist?(dir)

      meta = JSON.parse(File.read(File.join(dir, "metadata.json")), symbolize_names: true)

      if meta[:encrypted]
        key = keychain_fetch(session_name)
        {
          metadata: meta,
          cookies: decrypt_json(File.join(dir, "cookies.json.enc"), key, symbolize_names: true),
          local_storage: decrypt_json(File.join(dir, "local_storage.json.enc"), key, symbolize_names: false),
          session_storage: load_session_storage_encrypted(dir, key)
        }
      else
        {
          metadata: meta,
          cookies: JSON.parse(File.read(File.join(dir, "cookies.json")), symbolize_names: true),
          local_storage: JSON.parse(File.read(File.join(dir, "local_storage.json")), symbolize_names: false),
          session_storage: load_session_storage(dir)
        }
      end
    end

    def self.load_meta(path)
      JSON.parse(File.read(path), symbolize_names: true)
    rescue JSON::ParserError
      nil
    end

    def self.validate_name!(name)
      return if SAFE_NAME.match?(name.to_s)

      raise ArgumentError, "invalid session name #{name.inspect} — use letters, digits, _ or - (max 64 chars)"
    end

    # Encrypt data (JSON) and return binary blob: [12-byte nonce][ciphertext+16-byte tag]
    def self.encrypt_file(data, key)
      nonce = SecureRandom.bytes(12)
      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      cipher.encrypt
      cipher.key = key
      cipher.iv  = nonce
      ciphertext = cipher.update(data) + cipher.final
      tag        = cipher.auth_tag
      nonce + ciphertext + tag
    end
    private_class_method :encrypt_file

    # Decrypt binary blob produced by encrypt_file; returns original plaintext string.
    def self.decrypt_file(blob, key)
      nonce      = blob.byteslice(0, 12)
      tag        = blob.byteslice(-16, 16)
      ciphertext = blob.byteslice(12, blob.bytesize - 28)

      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      cipher.decrypt
      cipher.key      = key
      cipher.iv       = nonce
      cipher.auth_tag = tag
      cipher.update(ciphertext) + cipher.final
    rescue OpenSSL::Cipher::CipherError => e
      raise Browserctl::Error, "decryption failed: #{e.message}"
    end
    private_class_method :decrypt_file

    def self.keychain_store(name, key)
      hex_key = key.unpack1("H*")
      out, status = Open3.capture2(
        "security", "add-generic-password",
        "-a", name,
        "-s", "browserctl",
        "-w", hex_key,
        "-U"
      )
      raise Browserctl::Error, "keychain store failed: #{out}" unless status.success?
    end
    private_class_method :keychain_store

    def self.keychain_fetch(name)
      hex_key, status = Open3.capture2(
        "security", "find-generic-password",
        "-a", name,
        "-s", "browserctl",
        "-w"
      )
      raise Browserctl::Error, "keychain fetch failed for session '#{name}'" unless status.success?

      [hex_key.strip].pack("H*")
    end
    private_class_method :keychain_fetch

    def self.keychain_available?
      RUBY_PLATFORM.include?("darwin") && system("which security > /dev/null 2>&1")
    end
    private_class_method :keychain_available?

    def self.load_session_storage(dir)
      ss_path = File.join(dir, "session_storage.json")
      File.exist?(ss_path) ? JSON.parse(File.read(ss_path), symbolize_names: false) : {}
    end
    private_class_method :load_session_storage

    def self.load_session_storage_encrypted(dir, key)
      ss_path = File.join(dir, "session_storage.json.enc")
      return {} unless File.exist?(ss_path)

      decrypt_json(ss_path, key, symbolize_names: false)
    end
    private_class_method :load_session_storage_encrypted

    def self.decrypt_json(path, key, symbolize_names:)
      blob = File.binread(path)
      JSON.parse(decrypt_file(blob, key), symbolize_names: symbolize_names)
    end
    private_class_method :decrypt_json

    def self.write_json(path, data)
      File.write(path, JSON.generate(data))
    end
    private_class_method :write_json

    # Cookies and storage contain secrets — restrict to owner read/write only.
    def self.write_secret(path, data)
      File.open(path, "w", 0o600) { |f| f.write(JSON.generate(data)) }
    end
    private_class_method :write_secret

    def self.write_encrypted_secret(path, data, key)
      blob = encrypt_file(JSON.generate(data), key)
      File.open(path, "wb", 0o600) { |f| f.write(blob) }
    end
    private_class_method :write_encrypted_secret
  end
end

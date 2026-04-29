# frozen_string_literal: true

require "fileutils"
require "io/console"
require "json"
require "open3"
require "openssl"
require "securerandom"
require "tmpdir"
require_relative "cli_output"

module Browserctl
  module Commands
    module Session
      extend CliOutput

      USAGE = "Usage: browserctl session <save|load|list|delete|export|import> [args]"

      PBKDF2_ITERATIONS = 100_000
      PBKDF2_KEY_LEN    = 32
      SALT_LEN          = 16
      NONCE_LEN         = 12

      SENSITIVE_BASENAMES = %w[cookies.json local_storage.json session_storage.json].freeze

      def self.run(client, args)
        sub = args.shift or abort USAGE
        case sub
        when "save"   then run_save(client, args)
        when "load"   then run_load(client, args)
        when "list"   then run_list(client)
        when "delete" then run_delete(client, args)
        when "export" then run_export(args)
        when "import" then run_import(args)
        else abort "unknown session subcommand '#{sub}'\n#{USAGE}"
        end
      end

      def self.run_save(client, args)
        encrypt = args.delete("--encrypt")
        name    = args.shift or abort "usage: browserctl session save <name> [--encrypt]"
        print_result(client.session_save(name, encrypt: !!encrypt))
      end

      def self.run_load(client, args)
        name = args.shift or abort "usage: browserctl session load <name>"
        print_result(client.session_load(name))
      end

      def self.run_list(client)
        print_result(client.session_list)
      end

      def self.run_delete(client, args)
        name = args.shift or abort "usage: browserctl session delete <name>"
        print_result(client.session_delete(name))
      end

      def self.run_export(args)
        encrypt = args.delete("--encrypt")
        name    = args.shift or abort "usage: browserctl session export <name> <path> [--encrypt]"
        dest    = args.shift or abort "usage: browserctl session export <name> <path> [--encrypt]"

        session_dir = File.join(Browserctl::BROWSERCTL_DIR, "sessions", name)
        abort "session '#{name}' not found" unless Dir.exist?(session_dir)

        dest = File.expand_path(dest)

        if encrypt
          passphrase = prompt_passphrase
          encrypt_export(session_dir, name, dest, passphrase)
        else
          pid = Process.spawn("zip", "-r", dest, name, chdir: File.join(Browserctl::BROWSERCTL_DIR, "sessions"))
          Process.wait(pid)
        end

        puts({ ok: true, path: dest }.to_json)
      end

      def self.run_import(args)
        zip_path = args.shift or abort "usage: browserctl session import <path>"
        zip_path = File.expand_path(zip_path)
        abort "zip file not found: #{zip_path}" unless File.exist?(zip_path)

        sessions_dir = File.join(Browserctl::BROWSERCTL_DIR, "sessions")
        FileUtils.mkdir_p(sessions_dir)

        if encrypted_zip?(zip_path)
          passphrase = prompt_passphrase
          decrypt_import(zip_path, sessions_dir, passphrase)
        else
          pid = Process.spawn("unzip", "-o", zip_path, "-d", sessions_dir)
          Process.wait(pid)
        end

        puts({ ok: true }.to_json)
      end

      # --- private helpers ---

      def self.prompt_passphrase
        if ENV["BROWSERCTL_EXPORT_PASSPHRASE"]
          ENV["BROWSERCTL_EXPORT_PASSPHRASE"]
        else
          $stderr.print "Passphrase: "
          pass = $stdin.noecho(&:gets).to_s.chomp
          $stderr.puts
          pass
        end
      end
      private_class_method :prompt_passphrase

      def self.derive_key(passphrase, salt)
        OpenSSL::PKCS5.pbkdf2_hmac(
          passphrase,
          salt,
          PBKDF2_ITERATIONS,
          PBKDF2_KEY_LEN,
          OpenSSL::Digest.new("SHA256")
        )
      end
      private_class_method :derive_key

      def self.encrypt_blob(plaintext, key)
        nonce  = SecureRandom.bytes(NONCE_LEN)
        cipher = OpenSSL::Cipher.new("aes-256-gcm")
        cipher.encrypt
        cipher.key = key
        cipher.iv  = nonce
        ct  = cipher.update(plaintext) + cipher.final
        tag = cipher.auth_tag
        nonce + ct + tag
      end
      private_class_method :encrypt_blob

      def self.decrypt_blob(blob, key)
        nonce      = blob.byteslice(0, NONCE_LEN)
        tag        = blob.byteslice(-16, 16)
        ciphertext = blob.byteslice(NONCE_LEN, blob.bytesize - NONCE_LEN - 16)
        cipher = OpenSSL::Cipher.new("aes-256-gcm")
        cipher.decrypt
        cipher.key      = key
        cipher.iv       = nonce
        cipher.auth_tag = tag
        cipher.update(ciphertext) + cipher.final
      rescue OpenSSL::Cipher::CipherError => e
        raise Browserctl::Error, "export decryption failed: #{e.message}"
      end
      private_class_method :decrypt_blob

      # Build an encrypted zip using the system zip command.
      # Plaintext files are staged in a tmpdir; sensitive ones are encrypted
      # before staging. An _encryption_manifest.json is added at the zip root.
      def self.encrypt_export(session_dir, session_name, dest, passphrase)
        salt = SecureRandom.bytes(SALT_LEN)
        key  = derive_key(passphrase, salt)
        manifest = JSON.generate({
                                   encrypted: true, kdf: "pbkdf2-sha256",
                                   iterations: PBKDF2_ITERATIONS, salt: salt.unpack1("H*")
                                 })
        Dir.mktmpdir do |tmpdir|
          File.write(File.join(tmpdir, "_encryption_manifest.json"), manifest)
          stage_session_files(session_dir, session_name, tmpdir, key)
          pid = Process.spawn("zip", "-r", dest, "_encryption_manifest.json", session_name, chdir: tmpdir)
          Process.wait(pid)
        end
      end
      private_class_method :encrypt_export

      def self.stage_session_files(session_dir, session_name, tmpdir, key)
        staged_session = File.join(tmpdir, session_name)
        FileUtils.mkdir_p(staged_session)
        Dir[File.join(session_dir, "**", "*")].each do |file|
          next if File.directory?(file)

          relative    = file.delete_prefix("#{session_dir}/")
          staged_path = File.join(staged_session, relative)
          FileUtils.mkdir_p(File.dirname(staged_path))
          raw = File.binread(file)
          if SENSITIVE_BASENAMES.include?(File.basename(file))
            File.binwrite("#{staged_path}.enc", encrypt_blob(raw, key))
          else
            File.binwrite(staged_path, raw)
          end
        end
      end
      private_class_method :stage_session_files

      # Returns true if the zip contains _encryption_manifest.json.
      def self.encrypted_zip?(zip_path)
        out, status = Open3.capture2("unzip", "-l", zip_path)
        status.success? && out.include?("_encryption_manifest.json")
      end
      private_class_method :encrypted_zip?

      # Extract zip to tmpdir, read manifest, decrypt .enc files, copy to sessions_dir.
      def self.decrypt_import(zip_path, sessions_dir, passphrase)
        Dir.mktmpdir do |tmpdir|
          pid = Process.spawn("unzip", "-o", zip_path, "-d", tmpdir)
          Process.wait(pid)
          manifest_path = File.join(tmpdir, "_encryption_manifest.json")
          raise Browserctl::Error, "missing encryption manifest in zip" unless File.exist?(manifest_path)

          manifest = JSON.parse(File.read(manifest_path), symbolize_names: true)
          key = derive_key(passphrase, [manifest[:salt]].pack("H*"))
          copy_decrypted_files(tmpdir, sessions_dir, key)
        end
      end
      private_class_method :decrypt_import

      def self.copy_decrypted_files(tmpdir, sessions_dir, key)
        Dir[File.join(tmpdir, "**", "*")].each do |file|
          next if File.directory?(file)
          next if File.basename(file) == "_encryption_manifest.json"

          relative  = file.delete_prefix("#{tmpdir}/")
          dest_path = File.join(sessions_dir, relative)
          FileUtils.mkdir_p(File.dirname(dest_path))
          if file.end_with?(".enc")
            File.open(dest_path.delete_suffix(".enc"), "wb", 0o600) do |f|
              f.write(decrypt_blob(File.binread(file), key))
            end
          else
            FileUtils.cp(file, dest_path)
          end
        end
      end
      private_class_method :copy_decrypted_files
    end
  end
end

# frozen_string_literal: true

require "fileutils"
require "json"
require_relative "constants"

module Browserctl
  class Session
    BASE_DIR = File.join(BROWSERCTL_DIR, "sessions")

    SAFE_NAME = /\A[a-zA-Z0-9_-]{1,64}\z/

    def self.path(name)    = File.join(BASE_DIR, name)
    def self.exist?(name)  = Dir.exist?(path(name))

    def self.delete(name)
      validate_name!(name)
      FileUtils.rm_rf(path(name))
    end

    def self.all
      Dir[File.join(BASE_DIR, "*/metadata.json")].filter_map { |f| load_meta(f) }
    end

    def self.save(session_name, metadata:, cookies:, local_storage:, session_storage:)
      validate_name!(session_name)
      dir = path(session_name)
      FileUtils.mkdir_p(dir)
      write_json(File.join(dir, "metadata.json"),     metadata)
      write_secret(File.join(dir, "cookies.json"),    cookies)
      write_secret(File.join(dir, "local_storage.json"), local_storage)
      return if session_storage.empty?

      write_secret(File.join(dir, "session_storage.json"), session_storage)
    end

    def self.load(session_name)
      validate_name!(session_name)
      dir = path(session_name)
      raise "session '#{session_name}' not found" unless Dir.exist?(dir)

      {
        metadata: JSON.parse(File.read(File.join(dir, "metadata.json")), symbolize_names: true),
        cookies: JSON.parse(File.read(File.join(dir, "cookies.json")), symbolize_names: true),
        local_storage: JSON.parse(File.read(File.join(dir, "local_storage.json")), symbolize_names: false),
        session_storage: load_session_storage(dir)
      }
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

    def self.load_session_storage(dir)
      ss_path = File.join(dir, "session_storage.json")
      File.exist?(ss_path) ? JSON.parse(File.read(ss_path), symbolize_names: false) : {}
    end
    private_class_method :load_session_storage

    def self.write_json(path, data)
      File.write(path, JSON.generate(data))
    end
    private_class_method :write_json

    # Cookies and storage contain secrets — restrict to owner read/write only.
    def self.write_secret(path, data)
      File.open(path, "w", 0o600) { |f| f.write(JSON.generate(data)) }
    end
    private_class_method :write_secret
  end
end

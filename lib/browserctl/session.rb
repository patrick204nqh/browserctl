# frozen_string_literal: true

require "fileutils"
require "json"
require_relative "constants"

module Browserctl
  class Session
    BASE_DIR = File.join(BROWSERCTL_DIR, "sessions")

    def self.path(name)    = File.join(BASE_DIR, name)
    def self.exist?(name)  = Dir.exist?(path(name))
    def self.delete(name)  = FileUtils.rm_rf(path(name))

    def self.all
      Dir[File.join(BASE_DIR, "*/metadata.json")].filter_map { |f| load_meta(f) }
    end

    def self.save(session_name, metadata:, cookies:, local_storage:, session_storage:)
      dir = path(session_name)
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "metadata.json"), JSON.generate(metadata))
      File.write(File.join(dir, "cookies.json"),        JSON.generate(cookies))
      File.write(File.join(dir, "local_storage.json"),  JSON.generate(local_storage))
      return if session_storage.empty?

      File.write(File.join(dir, "session_storage.json"), JSON.generate(session_storage))
    end

    def self.load(session_name)
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

    def self.load_session_storage(dir)
      ss_path = File.join(dir, "session_storage.json")
      File.exist?(ss_path) ? JSON.parse(File.read(ss_path), symbolize_names: false) : {}
    end
    private_class_method :load_session_storage
  end
end

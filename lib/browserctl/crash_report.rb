# frozen_string_literal: true

require "json"
require "time"
require "fileutils"
require "etc"

require_relative "version"
require_relative "logger"

module Browserctl
  # Writes a local crash report JSON file when the daemon panics. No telemetry,
  # no upload — purely a local artifact users can attach to bug reports.
  #
  # The writer is intentionally defensive: it must never raise. If anything
  # goes wrong while writing the file, it falls back to a single
  # `[crash-report-failed]` line on stderr and returns nil.
  module CrashReport
    SCHEMA_VERSION = 1
    LAST_EVENTS_LIMIT = 50

    # @param error [Exception] the unhandled exception that took the daemon down
    # @param log_path [String, nil] path to the daemon's JSONL log; the last
    #   {LAST_EVENTS_LIMIT} valid records are tailed in
    # @return [String, nil] the path of the written crash file, or nil on failure
    def self.write(error:, log_path: nil)
      ts = Time.now.utc
      filename = "crash-#{ts.iso8601(3).gsub(':', '-')}.json"
      dir = Browserctl.log_dir
      FileUtils.mkdir_p(dir, mode: 0o700)
      path = File.join(dir, filename)

      payload = {
        schema_version: SCHEMA_VERSION,
        ts: ts.iso8601(3),
        daemon_version: Browserctl::VERSION,
        ruby_version: RUBY_VERSION,
        os: os_info,
        error: error_info(error),
        backtrace: Array(error.backtrace),
        last_events: tail_events(log_path)
      }

      File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |f|
        f.write(JSON.pretty_generate(payload))
      end
      path
    rescue StandardError => e
      warn "[crash-report-failed] #{e.class}: #{e.message}"
      nil
    end

    def self.os_info
      info = { platform: RUBY_PLATFORM }
      uname = Etc.uname
      info[:version] = uname[:version] if uname.is_a?(Hash) && uname[:version]
      info[:sysname] = uname[:sysname] if uname.is_a?(Hash) && uname[:sysname]
      info
    rescue StandardError
      { platform: RUBY_PLATFORM }
    end
    private_class_method :os_info

    def self.error_info(error)
      info = {
        class: error.class.name,
        message: error.message.to_s
      }
      info[:code] = error.code if error.respond_to?(:code) && error.code
      info
    end
    private_class_method :error_info

    def self.tail_events(log_path)
      return [] unless log_path && File.exist?(log_path)

      lines = File.readlines(log_path).last(LAST_EVENTS_LIMIT * 2)
      events = []
      lines.reverse_each do |line|
        line = line.strip
        next if line.empty?

        begin
          events.unshift(JSON.parse(line))
        rescue JSON::ParserError
          next
        end
        break if events.length >= LAST_EVENTS_LIMIT
      end
      events
    rescue StandardError
      []
    end
    private_class_method :tail_events
  end
end

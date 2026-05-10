# frozen_string_literal: true

require "fileutils"
require "json"
require "time"
require_relative "../errors"
require_relative "../error/codes"

module Browserctl
  class Recording
    # Owns recording-log file I/O: path resolution, header initialisation,
    # JSONL append, raw read, deletion, and format-version validation.
    #
    # All paths are resolved against the parent `Recording::RECORDINGS_DIR`
    # constant on each call so RSpec `stub_const` calls remain effective.
    module LogWriter
      module_function

      # Returns the on-disk JSONL path for a named recording.
      def log_path(name)
        File.join(Browserctl::Recording::RECORDINGS_DIR, "#{name}.jsonl")
      end

      # Truncates (or creates) the log for `name`, locks it down to user
      # permissions, and writes the `_meta` header line. Returns the path.
      def init_log(name)
        FileUtils.mkdir_p(Browserctl::Recording::RECORDINGS_DIR, mode: 0o700)
        path = log_path(name)
        FileUtils.rm_f(path)
        FileUtils.touch(path)
        File.chmod(0o600, path)
        File.open(path, "a") do |f|
          f.puts JSON.generate(
            cmd: "_meta",
            format_version: Browserctl::Recording::RECORDING_FORMAT_VERSION,
            log_format: Browserctl::Recording::LOG_FORMAT,
            recording: name,
            started_at: Time.now.utc.iso8601
          )
        end
        path
      end

      # Appends a single JSONL entry to the log for `name`.
      def append_entry(name, entry)
        File.open(log_path(name), "a") do |f|
          f.puts JSON.generate(entry)
        end
      end

      # Returns the parsed lines for `name`, with symbolised keys.
      def read_entries(name)
        File.readlines(log_path(name)).map { |l| JSON.parse(l, symbolize_names: true) }
      end

      # Removes the log file for `name` if present.
      def delete_log(name)
        FileUtils.rm_f(log_path(name))
      end

      # Raises Browserctl::ProtocolMismatch when the recording log's
      # `_meta` header is missing or declares a `format_version` that this
      # build does not support. Mirrors `Browserctl::State::Bundle`.
      def verify_format_version!(raw_lines, path: nil)
        meta = raw_lines.first
        version = meta && meta[:cmd] == "_meta" ? meta[:format_version] : nil
        supported = Browserctl::Recording::SUPPORTED_FORMAT_VERSIONS
        return if version && supported.include?(version)

        where = path ? " at #{path}" : ""
        msg = if version.nil?
                "recording log#{where} is missing format_version " \
                  "(supported: #{supported.inspect})"
              else
                "recording log#{where} declares format_version=#{version.inspect}, " \
                  "this build supports #{supported.inspect}"
              end
        raise Browserctl::ProtocolMismatch.new(msg, code: Browserctl::Error::Codes::PROTOCOL_MISMATCH)
      end
    end
  end
end

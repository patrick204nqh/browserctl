# frozen_string_literal: true

require "json"
require "fileutils"
require_relative "../constants"

module Browserctl
  module Replay
    # Append-only JSONL log of replay drift events for offline analysis.
    # Local-only; nothing is uploaded. One line per event.
    module Telemetry
      LOG_BASENAME = "replay_drift.jsonl"

      module_function

      def log_path
        File.join(Browserctl::BROWSERCTL_DIR, LOG_BASENAME)
      end

      # Write each drift event from a Replay::Context as its own JSONL line.
      # @param ctx [Browserctl::Replay::Context, nil]
      # @param workflow [String] workflow name for cross-reference
      # @param path [String] override the destination (testing)
      # @return [Integer] number of events written
      def emit(ctx, workflow:, path: log_path)
        events = ctx&.drift_events
        return 0 if events.nil? || events.empty?

        ensure_log_file(path)
        ts = Time.now.utc.iso8601
        File.open(path, "a") do |f|
          events.each do |e|
            f.puts JSON.generate(
              event: "replay_drift",
              ts: ts,
              workflow: workflow,
              command: e.command.to_s,
              selector: e.selector,
              matched_ref: e.matched_ref,
              score: e.score,
              reason: e.reason
            )
          end
        end
        events.size
      rescue SystemCallError, IOError
        # Telemetry must never break a run.
        0
      end

      def ensure_log_file(path)
        FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
        return if File.exist?(path)

        FileUtils.touch(path)
        File.chmod(0o600, path)
      end
    end
  end
end

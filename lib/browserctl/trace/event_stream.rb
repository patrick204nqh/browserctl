# frozen_string_literal: true

require "json"

module Browserctl
  module Trace
    # Reads `cli.log` + `daemon.log` JSONL files from a log directory and yields
    # records sorted by timestamp. Malformed lines are skipped silently — this
    # matches the tolerant behaviour expected of `browserctl trace`.
    #
    # Session filtering: when `session_filter` is provided, only records whose
    # `session_id` matches are emitted. When nil, records are scoped to the most
    # recent `session_id` observed in the merged stream (or all records if none
    # carry a session id yet — backwards compatible with older logs).
    class EventStream
      include Enumerable

      LOG_GLOB = "{cli,daemon}.log"

      def initialize(log_dir, session_filter: nil)
        @log_dir = log_dir
        @session_filter = session_filter
      end

      def each(&block)
        return enum_for(:each) unless block

        records.each(&block)
      end

      def empty?
        records.empty?
      end

      def records
        @records ||= filter_session(load_records)
      end

      private

      def load_records
        paths = Dir.glob(File.join(@log_dir, LOG_GLOB))
        rows = paths.flat_map do |path|
          File.foreach(path).filter_map { |line| parse_line(line) }
        end
        rows.sort_by { |r| r["ts"].to_s }
      end

      def parse_line(line)
        stripped = line.strip
        return nil if stripped.empty?

        JSON.parse(stripped)
      rescue JSON::ParserError
        nil
      end

      # Session resolution. When session_id is stamped on records (future PR),
      # filter/select by it. Otherwise, treat the entire merged stream as one
      # session — caller can scope by tailing/rotating logs.
      # See: https://github.com/patrick204nqh/browserctl/issues/212 — until
      # session_id is stamped on every log line by the writer, this is the
      # best-effort heuristic.
      def filter_session(rows)
        if @session_filter
          rows.select { |r| r["session_id"].to_s == @session_filter }
        else
          ids = rows.map { |r| r["session_id"] }.compact.uniq
          return rows if ids.empty?

          recent = ids.last
          rows.select { |r| r["session_id"] == recent }
        end
      end
    end
  end
end

# frozen_string_literal: true

require "json"
require "time"
require_relative "../logger"

module Browserctl
  module Commands
    # `browserctl trace [<session>]` — pretty timeline of structured log events
    # across cli.log + daemon.log. Defaults to most recent session.
    #
    # Loose categorisation by inspecting common keys (event/snapshot/request/
    # error). No schema is enforced — this command is tolerant of any JSONL
    # produced by Browserctl::JsonlFormatter.
    #
    # TODO(PR#15): redact secrets via `--redact` flag. This PR prints raw
    # log content as-is.
    module Trace
      USAGE = "Usage: browserctl trace [<session>]"

      LEVEL_COLORS = {
        "DEBUG" => "\e[2;37m", # dim grey
        "INFO" => "\e[36m",    # cyan
        "WARN" => "\e[33m",    # yellow
        "ERROR" => "\e[31m" # red
      }.freeze
      RESET = "\e[0m"

      CATEGORY_ICONS = {
        error: "!",
        snapshot: "S",
        network: "N",
        event: "."
      }.freeze

      OMIT_KEYS = %w[ts level component event msg].freeze

      def self.run(args, log_dir: Browserctl.log_dir, out: $stdout)
        abort USAGE if args.include?("-h") || args.include?("--help")
        session_filter = args.shift

        records = load_records(log_dir)
        if records.empty?
          out.puts "No log entries found in #{log_dir}"
          return
        end

        records = filter_session(records, session_filter)
        if records.empty?
          out.puts "No entries match session=#{session_filter}"
          return
        end

        render(records, out: out)
      end

      def self.load_records(log_dir)
        paths = Dir.glob(File.join(log_dir, "{cli,daemon}.log"))
        records = paths.flat_map do |path|
          File.foreach(path).filter_map { |line| parse_line(line) }
        end
        records.sort_by { |r| r["ts"].to_s }
      end

      def self.parse_line(line)
        line = line.strip
        return nil if line.empty?

        JSON.parse(line)
      rescue JSON::ParserError
        nil
      end

      # Session resolution. When session_id is stamped on records (future PR),
      # filter/select by it. Otherwise, treat the entire merged stream as one
      # session — caller can scope by tailing/rotating logs.
      # TODO: stamp session_id on every log line so this scopes correctly.
      def self.filter_session(records, session_filter)
        if session_filter
          records.select { |r| r["session_id"].to_s == session_filter }
        else
          ids = records.map { |r| r["session_id"] }.compact.uniq
          if ids.empty?
            records
          else
            recent = ids.last
            records.select { |r| r["session_id"] == recent }
          end
        end
      end

      def self.render(records, out:)
        tty = out.respond_to?(:tty?) && out.tty?
        records.each { |r| out.puts(format_line(r, tty: tty)) }
      end

      def self.format_line(record, tty:)
        level = (record["level"] || "INFO").to_s
        line  = format("%-12<ts>s %<icon>s %-5<level>s %-7<comp>s %-22<label>s %<ctx>s",
                       ts: format_ts(record["ts"]),
                       icon: CATEGORY_ICONS.fetch(categorise(record), "."),
                       level: level,
                       comp: (record["component"] || "?").to_s,
                       label: event_label(record),
                       ctx: context_snippet(record)).rstrip

        tty ? colourise(line, level) : line
      end

      def self.format_ts(timestamp)
        Time.iso8601(timestamp.to_s).strftime("%H:%M:%S.%L")
      rescue ArgumentError, TypeError
        "??:??:??.???"
      end

      def self.categorise(record)
        return :error    if record["level"] == "ERROR" || record["error"]
        return :snapshot if record["snapshot"]
        return :network  if record["request"] || record["response"] || record["url"]

        :event
      end

      def self.event_label(record)
        (record["event"] || record["snapshot"] || record["request"] ||
          record["msg"] || "-").to_s.slice(0, 22)
      end

      # Compact "k=v k=v" snippet of remaining structured keys, capped to keep
      # the timeline scannable. Skips fields already shown in fixed columns.
      def self.context_snippet(record)
        pairs = record.except(*OMIT_KEYS)
        return "" if pairs.empty?

        pairs.map { |k, v| "#{k}=#{format_value(v)}" }.join(" ").slice(0, 120)
      end

      def self.format_value(value)
        case value
        when String  then value.length > 40 ? "#{value[0, 37]}..." : value
        when Array   then "[#{value.length}]"
        when Hash    then "{#{value.keys.length}}"
        else value.to_s
        end
      end

      def self.colourise(line, level)
        colour = LEVEL_COLORS[level] || ""
        "#{colour}#{line}#{RESET}"
      end
    end
  end
end

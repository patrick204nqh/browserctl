# frozen_string_literal: true

require "json"
require "time"
require_relative "../logger"
require_relative "../redactor"
require_relative "../secret_resolver_registry"
require_relative "output_format"

module Browserctl
  module Commands
    # `browserctl trace [<session>] [--no-redact]` — pretty timeline of
    # structured log events across cli.log + daemon.log. Defaults to most
    # recent session.
    #
    # Loose categorisation by inspecting common keys (event/snapshot/request/
    # error). No schema is enforced — this command is tolerant of any JSONL
    # produced by Browserctl::JsonlFormatter.
    #
    # Redaction: ON by default. Secret values are sourced from current ENV
    # patterns (`*_TOKEN`, `*_KEY`, `*_SECRET`, `*_PASSWORD`) and any values
    # captured by `SecretResolverRegistry` during this process. Pass
    # `--no-redact` to disable (local debugging only). Note: when replaying
    # historical traces from a previous process, registry-captured values are
    # gone — only current ENV patterns apply.
    module Trace
      USAGE = "Usage: browserctl trace [<session>] [--no-redact]"
      NO_REDACT_WARNING = "[browserctl] traces include unredacted secret values; " \
                          "do not paste this output publicly."

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

      def self.run(args, log_dir: Browserctl.log_dir, out: $stdout, err: $stderr)
        abort USAGE if args.include?("-h") || args.include?("--help")
        args = args.dup
        redact = !args.delete("--no-redact")
        session_filter = args.shift
        redactor = resolve_redactor(redact, err)
        records = collect_records(log_dir, session_filter, out)
        emit_records(records, redactor, out) if records
      end

      def self.resolve_redactor(redact, err)
        return nil unless redact

        build_redactor
      ensure
        warn_no_redact(err) unless redact
      end

      def self.collect_records(log_dir, session_filter, out)
        records = load_records(log_dir)
        if records.empty?
          emit_empty("No log entries found in #{log_dir}", out)
          return nil
        end

        records = filter_session(records, session_filter)
        if records.empty?
          emit_empty("No entries match session=#{session_filter}", out)
          return nil
        end

        records
      end

      def self.emit_empty(message, out)
        OutputFormat.current.emit({ records: [], message: message }, message, io: out)
      end

      def self.emit_records(records, redactor, out)
        fmt = OutputFormat.current
        if fmt.json?
          fmt.emit({ records: records.map { |r| redact_record(r, redactor) } }, io: out)
        elsif !fmt.silent?
          render(records, out: out, redactor: redactor)
        end
      end

      def self.redact_record(record, redactor)
        return record unless redactor

        line = JSON.generate(record)
        JSON.parse(redactor.redact(line))
      rescue JSON::ParserError
        record
      end

      def self.build_redactor
        extra = if defined?(Browserctl::SecretResolverRegistry)
                  Browserctl::SecretResolverRegistry.resolved_values
                else
                  []
                end
        Browserctl::Redactor.from_env(extra: extra)
      rescue StandardError
        Browserctl::Redactor.new(secrets: [])
      end

      def self.warn_no_redact(err)
        err&.puts NO_REDACT_WARNING
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

      def self.render(records, out:, redactor: nil)
        tty = out.respond_to?(:tty?) && out.tty?
        records.each { |r| out.puts(format_line(r, tty: tty, redactor: redactor)) }
      end

      def self.format_line(record, tty:, redactor: nil)
        level = (record["level"] || "INFO").to_s
        line  = format("%-12<ts>s %<icon>s %-5<level>s %-7<comp>s %-22<label>s %<ctx>s",
                       ts: format_ts(record["ts"]),
                       icon: CATEGORY_ICONS.fetch(categorise(record), "."),
                       level: level,
                       comp: (record["component"] || "?").to_s,
                       label: event_label(record),
                       ctx: context_snippet(record)).rstrip

        line = redactor.redact(line) if redactor
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

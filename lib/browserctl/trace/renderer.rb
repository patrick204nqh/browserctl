# frozen_string_literal: true

require "time"

module Browserctl
  module Trace
    # Renders structured log records as a human-scannable timeline. Output
    # format is intentionally compact:
    #
    #   HH:MM:SS.mmm I LEVEL COMPONENT LABEL                  k=v k=v
    #
    # Colour is enabled when the target IO is a TTY (or when `color: true` is
    # forced). Redaction is optional and injected as a dependency so callers
    # can substitute a stricter `Browserctl::Redactor` or pass `nil` to
    # disable.
    class Renderer
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

      def initialize(io:, color: nil, redactor: nil)
        @io = io
        @color = color.nil? ? tty?(io) : color
        @redactor = redactor
      end

      def render(stream)
        stream.each { |record| @io.puts(format_line(record)) }
      end

      private

      def tty?(io)
        io.respond_to?(:tty?) && io.tty?
      end

      def format_line(record)
        level = (record["level"] || "INFO").to_s
        line  = format("%-12<ts>s %<icon>s %-5<level>s %-7<comp>s %-22<label>s %<ctx>s",
                       ts: format_ts(record["ts"]),
                       icon: CATEGORY_ICONS.fetch(categorise(record), "."),
                       level: level,
                       comp: (record["component"] || "?").to_s,
                       label: event_label(record),
                       ctx: context_snippet(record)).rstrip

        line = @redactor.redact(line) if @redactor
        @color ? colourise(line, level) : line
      end

      def format_ts(timestamp)
        Time.iso8601(timestamp.to_s).strftime("%H:%M:%S.%L")
      rescue ArgumentError, TypeError
        "??:??:??.???"
      end

      def categorise(record)
        return :error    if record["level"] == "ERROR" || record["error"]
        return :snapshot if record["snapshot"]
        return :network  if record["request"] || record["response"] || record["url"]

        :event
      end

      def event_label(record)
        (record["event"] || record["snapshot"] || record["request"] ||
          record["msg"] || "-").to_s.slice(0, 22)
      end

      # Compact "k=v k=v" snippet of remaining structured keys, capped to keep
      # the timeline scannable. Skips fields already shown in fixed columns.
      def context_snippet(record)
        pairs = record.except(*OMIT_KEYS)
        return "" if pairs.empty?

        pairs.map { |k, v| "#{k}=#{format_value(v)}" }.join(" ").slice(0, 120)
      end

      def format_value(value)
        case value
        when String  then value.length > 40 ? "#{value[0, 37]}..." : value
        when Array   then "[#{value.length}]"
        when Hash    then "{#{value.keys.length}}"
        else value.to_s
        end
      end

      def colourise(line, level)
        colour = LEVEL_COLORS[level] || ""
        "#{colour}#{line}#{RESET}"
      end
    end
  end
end

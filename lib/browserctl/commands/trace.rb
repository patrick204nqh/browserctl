# frozen_string_literal: true

require "json"
require_relative "../logger"
require_relative "../redactor"
require_relative "../secret_resolver_registry"
require_relative "../trace/event_stream"
require_relative "../trace/renderer"
require_relative "output_format"

module Browserctl
  module Commands
    # `browserctl trace [<session>] [--no-redact]` — pretty timeline of
    # structured log events across cli.log + daemon.log. Thin CLI dispatcher;
    # parsing lives in `Browserctl::Trace::EventStream`, rendering in
    # `Browserctl::Trace::Renderer`, redaction in `Browserctl::Redactor`.
    module Trace
      USAGE = "Usage: browserctl trace [<session>] [--no-redact]"
      NO_REDACT_WARNING = "[browserctl] traces include unredacted secret values; " \
                          "do not paste this output publicly."

      def self.run(args, log_dir: Browserctl.log_dir, out: $stdout, err: $stderr)
        abort USAGE if args.include?("-h") || args.include?("--help")
        args = args.dup
        redact = !args.delete("--no-redact")
        session_filter = args.shift
        redactor = redact ? build_redactor : (warn_no_redact(err) || nil)

        stream = Browserctl::Trace::EventStream.new(log_dir, session_filter: session_filter)
        if stream.empty?
          emit_empty(empty_message(log_dir, session_filter), out)
          return
        end

        emit(stream, redactor, out)
      end

      def self.emit(stream, redactor, out)
        fmt = OutputFormat.current
        if fmt.json?
          fmt.emit({ records: stream.records.map { |r| redact_record(r, redactor) } }, io: out)
        elsif !fmt.silent?
          Browserctl::Trace::Renderer.new(io: out, redactor: redactor).render(stream)
        end
      end

      def self.empty_message(log_dir, session_filter)
        session_filter ? "No entries match session=#{session_filter}" : "No log entries found in #{log_dir}"
      end

      def self.emit_empty(message, out)
        OutputFormat.current.emit({ records: [], message: message }, message, io: out)
      end

      def self.redact_record(record, redactor)
        return record unless redactor

        JSON.parse(redactor.redact(JSON.generate(record)))
      rescue JSON::ParserError
        record
      end

      def self.build_redactor
        extra = defined?(Browserctl::SecretResolverRegistry) ? Browserctl::SecretResolverRegistry.resolved_values : []
        Browserctl::Redactor.from_env(extra: extra)
      rescue StandardError
        Browserctl::Redactor.new(secrets: [])
      end

      def self.warn_no_redact(err)
        err&.puts NO_REDACT_WARNING
        nil
      end
    end
  end
end

# frozen_string_literal: true

require "json"

module Browserctl
  module Commands
    # Resolves and applies the unified `--output {json,text,silent}` flag.
    #
    # Resolution order: explicit flag value -> `BROWSERCTL_OUTPUT` env var ->
    # `text` (default).
    #
    # Usage from a command:
    #
    #   fmt = OutputFormat.from(flag, ENV)
    #   fmt.emit(payload_hash) { "human readable text" }
    #
    # Per the v0.13 contract:
    #
    #   text   - prints the human-readable block; this is byte-identical to
    #            today's output. For most commands the human block already IS
    #            the JSON payload (legacy CLI shape) so the two collapse.
    #   json   - prints the JSON payload via `to_json` (no pretty printing).
    #   silent - prints nothing on stdout. Exit codes still carry the result.
    #
    # The current format is also exposed as a process-wide default
    # (`OutputFormat.current`) so that `CliOutput#print_result` and other
    # legacy helpers can consult it without every callsite threading the
    # value through.
    module OutputFormat
      VALID = %w[json text silent].freeze
      DEFAULT = "text"
      ENV_VAR = "BROWSERCTL_OUTPUT"
      FLAG = "--output"

      class InvalidFormat < ArgumentError; end

      class Formatter
        attr_reader :mode

        def initialize(mode)
          @mode = mode
        end

        # Print success output for a command.
        # `payload` is a JSON-serialisable Hash (or Array). `text_block` is
        # either a String or a block that returns a String — only evaluated
        # when needed.
        def emit(payload, text_block = nil, io: $stdout)
          case @mode
          when "silent"
            nil
          when "json"
            io.puts payload.to_json
          else # "text"
            text = if block_given?
                     yield
                   elsif text_block.respond_to?(:call)
                     text_block.call
                   elsif text_block.nil?
                     payload.to_json
                   else
                     text_block
                   end
            io.puts text
          end
        end

        def silent?
          @mode == "silent"
        end

        def json?
          @mode == "json"
        end

        def text?
          @mode == "text"
        end
      end

      module_function

      # Build a Formatter from an explicit flag value (or nil) and an env hash.
      def from(flag, env = ENV)
        raw = flag || env[ENV_VAR] || DEFAULT
        mode = raw.to_s.strip.downcase
        mode = DEFAULT if mode.empty?
        unless VALID.include?(mode)
          raise InvalidFormat,
                "invalid --output value '#{raw}' (expected one of: #{VALID.join(', ')})"
        end
        Formatter.new(mode)
      end

      # Strip `--output VALUE` (or `--output=VALUE`) from `args` in place and
      # return the extracted value (or nil). Recognises the long form only —
      # there is intentionally no short alias.
      def extract!(args)
        i = 0
        while i < args.length
          arg = args[i]
          if arg == FLAG
            args.delete_at(i)
            value = args.delete_at(i) or
              raise InvalidFormat, "missing value for #{FLAG}"
            return value
          elsif arg.is_a?(String) && arg.start_with?("#{FLAG}=")
            value = arg.split("=", 2)[1]
            args.delete_at(i)
            return value
          else
            i += 1
          end
        end
        nil
      end

      # Process-wide current format. Set once by the CLI entry point after
      # parsing the global flag; consulted by helpers that don't otherwise
      # have a reference to a Formatter (notably `CliOutput#print_result`).
      def current
        @current ||= Formatter.new(DEFAULT)
      end

      def current=(formatter)
        @current = formatter
      end

      # Convenience: parse the flag out of `args`, build a Formatter, set it
      # as current, and return it.
      def install!(args, env = ENV)
        flag = extract!(args)
        fmt  = from(flag, env)
        self.current = fmt
        fmt
      end

      # Reset to default — for tests.
      def reset!
        @current = Formatter.new(DEFAULT)
      end
    end
  end
end

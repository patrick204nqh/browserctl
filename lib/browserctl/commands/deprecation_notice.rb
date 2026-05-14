# frozen_string_literal: true

require_relative "output_format"

module Browserctl
  module Commands
    # One-shot deprecation warning emitter for v0.15 alias verbs.
    #
    # Per ADR-0021: when a CLI invocation uses `cookie *` or `storage *`,
    # we emit exactly one line to stderr — never under `--output json`, so
    # JSON consumers (AI agents, scripts) keep a clean parser input. The
    # warning is memoised process-wide so a single CLI invocation only ever
    # prints it once even if a wrapper calls the dispatcher multiple times.
    module DeprecationNotice
      REMOVAL = "Removed at 1.0."

      module_function

      def emit(old_verb, replacement, io: $stderr)
        return if @emitted
        return if OutputFormat.current.json?

        @emitted = true
        io.puts "warning: '#{old_verb}' is deprecated; use '#{replacement}'. #{REMOVAL}"
      end

      # Test-only — reset memoisation between examples.
      def reset!
        @emitted = false
      end
    end
  end
end

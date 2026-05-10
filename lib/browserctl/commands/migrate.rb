# frozen_string_literal: true

require_relative "../migrations"
require_relative "../errors"
require_relative "../error/codes"
require_relative "../error/exit_codes"
require_relative "output_format"

module Browserctl
  module Commands
    # `browserctl migrate <path> [--to-version N] [--dry-run]` — operator
    # entry point for the {Browserctl::Migrations} registry. Detects the
    # artifact's format and version, plans a chain of registered upgraders,
    # and applies them in order (unless `--dry-run`).
    #
    # The registry ships empty in v0.12; this command exists so operators
    # have a stable invocation the moment a real migration lands. On an
    # already-current artifact the command is a no-op and exits 0.
    module Migrate
      USAGE = "Usage: browserctl migrate <path> [--to-version N] [--dry-run]"

      def self.run(args, out: $stdout, err: $stderr)
        abort USAGE if args.empty? || args.include?("-h") || args.include?("--help")
        args = args.dup

        dry_run    = !args.delete("--dry-run").nil?
        target_idx = args.index("--to-version")
        target = if target_idx
                   args.delete_at(target_idx)
                   Integer(args.delete_at(target_idx))
                 end
        path = args.shift
        abort USAGE unless path

        unless File.exist?(path)
          err.puts "Error: file not found: #{path}"
          exit Browserctl::Error::ExitCodes::GENERIC
        end

        execute(path, target_version: target, dry_run: dry_run, out: out, err: err)
      rescue Browserctl::ProtocolMismatch => e
        err.puts "Error: #{e.message}"
        exit Browserctl::Error::ExitCodes.for(e.code)
      end

      def self.execute(path, target_version:, dry_run:, out:, err:)
        format = detect_format!(path, err: err)
        current = Browserctl::Migrations.detect_version(path, format)
        emit_detected(format, current, path, out)

        return plan_dry_run(format, current, target_version, out) if dry_run

        result = Browserctl::Migrations.run(path, target_version: target_version)
        emit_applied(format, current, result, out)
      end

      def self.detect_format!(path, err:)
        format = Browserctl::Migrations.detect_format(path)
        return format if format

        err.puts "Error: could not detect format for #{path} (expected .bctl, .jsonl, or .rb)"
        exit Browserctl::Error::ExitCodes::PROTOCOL_MISMATCH
      end
      private_class_method :detect_format!

      def self.emit_detected(format, current, path, out)
        return unless OutputFormat.current.text?

        out.puts "Detected: format=#{format} version=#{current.inspect} path=#{path}"
      end
      private_class_method :emit_detected

      def self.emit_applied(format, current, result, out)
        fmt = OutputFormat.current
        if fmt.json?
          fmt.emit({ ok: true, format: format, from: result.from, to: result.to,
                     applied: result.applied.map { |m| { from: m.from_version, to: m.to_version } } },
                   io: out)
          return
        end
        return if fmt.silent?

        if result.applied.empty?
          out.puts "No migrations registered for #{format} v#{current}; nothing to do."
        else
          out.puts "Applied #{result.applied.size} migration(s): #{result.from} -> #{result.to}"
          result.applied.each { |m| out.puts "  - #{format} v#{m.from_version} -> v#{m.to_version}" }
        end
      end
      private_class_method :emit_applied

      def self.plan_dry_run(format, current, target_version, out)
        target = target_version || latest_target(format, current)
        chain  = Browserctl::Migrations.find_path(format: format, from: current, to: target)
        emit_plan(format, current, target, chain, out)
      end

      def self.emit_plan(format, current, target, chain, out)
        fmt = OutputFormat.current
        if fmt.json?
          fmt.emit(plan_payload(format, current, target, chain), io: out)
          return
        end
        return if fmt.silent?

        emit_plan_text(format, current, target, chain, out)
      end
      private_class_method :emit_plan

      def self.plan_payload(format, current, target, chain)
        {
          format: format, from: current, to: target, dry_run: true,
          plan: chain&.map { |m| { from: m.from_version, to: m.to_version } },
          registered: registered_for(format)
        }
      end
      private_class_method :plan_payload

      def self.emit_plan_text(format, current, target, chain, out)
        if chain.nil?
          out.puts "No migration path #{format} v#{current} -> v#{target} (registered: " \
                   "#{registered_for(format).inspect})"
        elsif chain.empty?
          out.puts "Already at v#{target}; no migrations would run."
        else
          out.puts "Plan (#{chain.size} step(s)):"
          chain.each { |m| out.puts "  - #{format} v#{m.from_version} -> v#{m.to_version}" }
        end
      end
      private_class_method :emit_plan_text

      def self.latest_target(format, current)
        targets = registered_for(format)
        targets.empty? ? current : targets.max
      end

      def self.registered_for(format)
        Browserctl::Migrations.all.select { |m| m.format == format }.map(&:to_version)
      end
    end
  end
end

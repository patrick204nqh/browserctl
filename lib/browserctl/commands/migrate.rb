# frozen_string_literal: true

require_relative "../migrations"
require_relative "../errors"
require_relative "../error/codes"
require_relative "../error/exit_codes"

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
        format = Browserctl::Migrations.detect_format(path)
        unless format
          err.puts "Error: could not detect format for #{path} (expected .bctl, .jsonl, or .rb)"
          exit Browserctl::Error::ExitCodes::PROTOCOL_MISMATCH
        end

        current = Browserctl::Migrations.detect_version(path, format)
        out.puts "Detected: format=#{format} version=#{current.inspect} path=#{path}"

        if dry_run
          plan_dry_run(format, current, target_version, out)
          return
        end

        result = Browserctl::Migrations.run(path, target_version: target_version)
        if result.applied.empty?
          out.puts "No migrations registered for #{format} v#{current}; nothing to do."
        else
          out.puts "Applied #{result.applied.size} migration(s): #{result.from} -> #{result.to}"
          result.applied.each { |m| out.puts "  - #{format} v#{m.from_version} -> v#{m.to_version}" }
        end
      end

      def self.plan_dry_run(format, current, target_version, out)
        target = target_version || latest_target(format, current)
        chain  = Browserctl::Migrations.find_path(format: format, from: current, to: target)

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

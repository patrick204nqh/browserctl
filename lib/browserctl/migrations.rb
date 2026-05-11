# frozen_string_literal: true

require "json"
require_relative "errors"
require_relative "error/codes"

module Browserctl
  # Migration registry for browserctl persisted formats. Operators run
  # `browserctl migrate <path>` to upgrade an artifact written by an older
  # browserctl to the current build's format version.
  #
  # Distinct from `verify_format_version!` (in bundle/recording/workflow):
  # those gates stay strict — a reader that encounters an unknown version
  # raises {Browserctl::ProtocolMismatch}. This module is the only blessed
  # path to mutate an old artifact in place.
  #
  # The registry ships **empty** in v0.12. The first real migration arrives
  # only when a format actually changes post-1.0. See
  # `docs/reference/format-versions.md` ("Migration registry").
  module Migrations
    # Single registered upgrader. `upgrade` is a Proc invoked with the
    # absolute path of the file being migrated; it is responsible for
    # rewriting that file in place, advancing it from `from_version` to
    # `to_version`.
    Migration = Struct.new(:format, :from_version, :to_version, :upgrade, keyword_init: true)

    # Result of {.run}. `applied` is the ordered list of {Migration} steps
    # that ran. When the artifact was already at target, `applied` is empty.
    Result = Struct.new(:format, :from, :to, :applied, keyword_init: true)

    FORMAT_EXTENSIONS = {
      ".bctl" => :bundle,
      ".jsonl" => :recording,
      ".rb" => :workflow
    }.freeze

    @registry = []
    @mutex = Mutex.new

    class << self
      # Registers an upgrader for one hop in `format`'s version chain. The
      # block receives the file path as a keyword argument and must rewrite
      # the file in place to the new version.
      def register(format:, from_version:, to_version:, &upgrade)
        unless upgrade
          raise Browserctl::Error.new(
            "upgrade block required",
            code: Browserctl::Error::Codes::INVALID_DSL_USAGE,
            context: { dsl: :migrations, action: :register, format: format,
                       from_version: from_version, to_version: to_version }
          )
        end

        @mutex.synchronize do
          @registry << Migration.new(format: format, from_version: from_version,
                                     to_version: to_version, upgrade: upgrade)
        end
      end

      # All registered migrations, in registration order.
      def all
        @mutex.synchronize { @registry.dup }
      end

      # Test-only hook — clears the registry. Not part of the public API.
      def reset!
        @mutex.synchronize { @registry.clear }
      end

      # Breadth-first search through registered migrations to chain a path
      # for `format` from `from` to `to`. Returns the ordered list of
      # {Migration} hops, or `nil` if no path is reachable. When `from == to`
      # returns an empty array (already at target — no work to do).
      def find_path(format:, from:, to:)
        return [] if from == to

        all_for_format = all.select { |m| m.format == format }
        queue = [[from, []]]
        seen  = { from => true }

        until queue.empty?
          current, path = queue.shift
          all_for_format.each do |m|
            next unless m.from_version == current
            next if seen[m.to_version]

            new_path = path + [m]
            return new_path if m.to_version == to

            seen[m.to_version] = true
            queue << [m.to_version, new_path]
          end
        end
        nil
      end

      # Inspects an artifact path and returns a format symbol — `:bundle`,
      # `:recording`, or `:workflow` — or `nil` when the format cannot be
      # identified. Detection is extension-driven: keep new formats listed
      # in {FORMAT_EXTENSIONS} so this stays a one-line lookup.
      def detect_format(path)
        FORMAT_EXTENSIONS[File.extname(path.to_s).downcase]
      end

      # Reads `path` and returns the integer format_version it declares, or
      # `nil` when no version header is present. Format-specific because
      # each format stores the header differently — the bundle in its
      # binary manifest, the recording in a `_meta` JSONL line, the
      # workflow in a Ruby comment.
      def detect_version(path, format)
        case format
        when :bundle    then peek_bundle_version(path)
        when :recording then peek_recording_version(path)
        when :workflow  then peek_workflow_version(path)
        end
      end

      # End-to-end migration. Detects format and current version, finds a
      # chain of registered upgraders to `target_version` (or the latest
      # `to_version` seen for this format if `target_version` is nil), and
      # invokes each in order. Each upgrader rewrites the file in place.
      #
      # Returns a {Result}. When no migrations are needed (or the registry
      # has no entries for this format), `applied` is empty.
      #
      # Raises {Browserctl::ProtocolMismatch} when format detection fails,
      # the version cannot be read, or no chain reaches the target.
      def run(path, target_version: nil)
        format  = detect_format(path) or raise_protocol("could not detect format for #{path}")
        current = detect_version(path, format) or raise_protocol("could not read format_version from #{path}")
        target  = target_version || latest_known_target(format, current)

        if current == target
          # If we'd be a no-op but the artifact's declared version is one this
          # build's reader does not support, surface that as PROTOCOL_MISMATCH —
          # there is no migration registered to bring it into range.
          unless format_version_supported?(format, current)
            raise_protocol("#{format} at #{path} declares unsupported format_version=#{current}; " \
                           "no migration registered")
          end
          return Result.new(format: format, from: current, to: current, applied: [])
        end

        chain = find_path(format: format, from: current, to: target)
        raise_protocol("no migration path from #{format} v#{current} to v#{target}") if chain.nil?

        chain.each { |m| m.upgrade.call(path: path, from_version: m.from_version, to_version: m.to_version) }
        Result.new(format: format, from: current, to: target, applied: chain)
      end

      private

      # Reflects whether each format's reader currently accepts a given
      # version. Mirrors the SUPPORTED_FORMAT_VERSIONS constant on the
      # corresponding class — kept here so adding a new format is one
      # branch, not a new public API.
      def format_version_supported?(format, version)
        case format
        when :bundle
          require_relative "state/bundle"
          Browserctl::State::Bundle::SUPPORTED_FORMAT_VERSIONS.include?(version)
        when :recording
          require_relative "recording"
          Browserctl::Recording::SUPPORTED_FORMAT_VERSIONS.include?(version)
        when :workflow
          require_relative "workflow"
          Browserctl::SUPPORTED_WORKFLOW_FORMAT_VERSIONS.include?(version)
        else
          false
        end
      end

      def latest_known_target(format, current)
        targets = all.select { |m| m.format == format }.map(&:to_version)
        targets.empty? ? current : targets.max
      end

      def peek_bundle_version(path)
        require_relative "state/bundle"
        manifest = Browserctl::State::Bundle.peek_manifest(File.binread(path))
        manifest[:format_version] || manifest["format_version"]
      rescue Browserctl::ProtocolMismatch
        # `peek_manifest` raises on unknown versions, but we want to *return*
        # the version so a migration can target it. Re-parse the manifest
        # bytes directly when the strict gate refuses.
        peek_bundle_version_loosely(path)
      end

      def peek_bundle_version_loosely(path)
        blob = File.binread(path)
        # Manifest length is at byte offset 8 (5 magic + 3 header). Parse
        # the JSON without invoking Bundle's strict version check.
        manifest_len = blob.byteslice(8, 4).unpack1("N")
        manifest_bytes = blob.byteslice(12, manifest_len)
        manifest = JSON.parse(manifest_bytes)
        manifest["format_version"]
      rescue StandardError
        nil
      end

      def peek_recording_version(path)
        first_line = File.foreach(path).first
        return nil unless first_line

        meta = JSON.parse(first_line, symbolize_names: true)
        return nil unless meta[:cmd] == "_meta"

        meta[:format_version]
      rescue JSON::ParserError
        nil
      end

      def peek_workflow_version(path)
        require_relative "workflow"
        Browserctl.parse_workflow_format_version(File.read(path))
      end

      def raise_protocol(msg)
        raise Browserctl::ProtocolMismatch.new(msg, code: Browserctl::Error::Codes::PROTOCOL_MISMATCH)
      end
    end
  end
end

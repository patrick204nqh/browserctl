# frozen_string_literal: true

require "json"
require "fileutils"
require "time"
require_relative "../constants"

module Browserctl
  module Workflow
    # Append-only JSONL ledger of `workflow run --check` outcomes per workflow.
    # Used as the gate for `workflow promote`: only workflows with a sufficient
    # streak of clean runs are eligible for promotion to `~/.browserctl/workflows/`.
    #
    # Record schema (one JSONL line):
    #   { "ts": "2026-05-10T12:00:00Z", "workflow": "name", "verdict": "clean" }
    module PromotionLedger
      LEDGER_BASENAME = "check_ledger.jsonl"
      DEFAULT_THRESHOLD = 3
      VALID_VERDICTS = %i[clean drift fail].freeze

      module_function

      def ledger_path
        File.join(Browserctl::BROWSERCTL_DIR, LEDGER_BASENAME)
      end

      # Append a verdict for a workflow run.
      # @param workflow [String]
      # @param verdict [Symbol] :clean, :drift, or :fail
      # @param path [String] override (testing)
      def record(workflow:, verdict:, path: ledger_path, at: Time.now.utc)
        return unless VALID_VERDICTS.include?(verdict)

        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, "a") do |f|
          f.puts JSON.generate(
            ts: at.iso8601,
            workflow: workflow.to_s,
            verdict: verdict.to_s
          )
        end
      end

      # Count the trailing streak of :clean verdicts for a workflow.
      # A non-clean verdict resets the streak. Drift and fail both break it
      # — the gate is intentionally strict; users can override with --force.
      # @return [Integer]
      def clean_streak(workflow:, path: ledger_path)
        return 0 unless File.exist?(path)

        streak = 0
        File.foreach(path) do |line|
          entry = parse(line) or next
          next unless entry["workflow"] == workflow.to_s

          if entry["verdict"] == "clean"
            streak += 1
          else
            streak = 0
          end
        end
        streak
      end

      def parse(line)
        JSON.parse(line)
      rescue JSON::ParserError
        nil
      end
    end
  end
end

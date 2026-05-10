# frozen_string_literal: true

require "fileutils"
require_relative "../constants"
require_relative "promotion_ledger"

module Browserctl
  module Workflow
    # Promotes a workflow file from the project-local `.browserctl/workflows/`
    # directory to the user-global `~/.browserctl/workflows/` directory, where
    # it is invocable from any project.
    #
    # Promotion is gated by `PromotionLedger.clean_streak`: a workflow must
    # have at least `threshold` consecutive clean `--check` runs before it
    # can be promoted. `--force` overrides the gate.
    module Promoter
      class IneligibleError < StandardError
        attr_reader :streak, :threshold

        def initialize(workflow:, streak:, threshold:)
          @streak = streak
          @threshold = threshold
          super(
            "workflow '#{workflow}' has #{streak} clean --check run(s); " \
            "needs #{threshold}. Run `browserctl workflow run #{workflow} --check` " \
            "until clean, or pass --force to override."
          )
        end
      end

      class NotFoundError < StandardError; end

      module_function

      DEFAULT_SOURCE_DIR = ".browserctl/workflows"

      def target_dir
        File.join(Browserctl::BROWSERCTL_DIR, "workflows")
      end

      def source_path(workflow, source_dir: DEFAULT_SOURCE_DIR)
        File.join(source_dir, "#{workflow}.rb")
      end

      def target_path(workflow)
        File.join(target_dir, "#{workflow}.rb")
      end

      # @param workflow [String]
      # @param force [Boolean]
      # @param threshold [Integer]
      # @param source_dir [String] override the source directory (testing)
      # @param ledger_path [String] override the ledger path (testing)
      # @return [Hash] `{ workflow:, source:, target:, streak:, threshold:, forced: }`
      def promote(workflow:, force: false, threshold: PromotionLedger::DEFAULT_THRESHOLD,
                  source_dir: DEFAULT_SOURCE_DIR, ledger_path: PromotionLedger.ledger_path)
        src = source_path(workflow, source_dir: source_dir)
        raise NotFoundError, "workflow file not found: #{src}" unless File.exist?(src)

        streak = PromotionLedger.clean_streak(workflow: workflow, path: ledger_path)
        unless force || streak >= threshold
          raise IneligibleError.new(workflow: workflow, streak: streak, threshold: threshold)
        end

        dst = target_path(workflow)
        FileUtils.mkdir_p(File.dirname(dst))
        FileUtils.cp(src, dst)

        {
          workflow: workflow,
          source: src,
          target: dst,
          streak: streak,
          threshold: threshold,
          forced: force && streak < threshold
        }
      end
    end
  end
end

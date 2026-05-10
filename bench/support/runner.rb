# frozen_string_literal: true

require "json"
require "fileutils"
require_relative "target"

module Browserctl
  module Bench
    # Loads benchmark target files and runs them, writing JSON results to
    # `bench/results/`. The runner is a plain Ruby module — there is no DSL,
    # no auto-discovery surprise: each target file lives in `bench/targets/`
    # and assigns a `Browserctl::Bench::Target` instance to
    # `Browserctl::Bench::CURRENT_TARGET` when loaded.
    module Runner
      module_function

      ROOT        = File.expand_path("../..", __dir__)
      TARGETS_DIR = File.join(ROOT, "bench", "targets")
      RESULTS_DIR = File.join(ROOT, "bench", "results")

      # Returns sorted target names discovered in `bench/targets/`.
      def all_targets
        Dir.glob(File.join(TARGETS_DIR, "*.rb")).map { |p| File.basename(p, ".rb") }.sort
      end

      # Loads a target by either bare name (`bundle_codec`) or path
      # (`bench/targets/bundle_codec.rb`). Returns the Target instance the
      # file installed into `CURRENT_TARGET`.
      def load_target(name_or_path)
        path = if File.exist?(name_or_path)
                 File.expand_path(name_or_path)
               else
                 File.join(TARGETS_DIR, "#{name_or_path}.rb")
               end
        raise ArgumentError, "no such target: #{name_or_path}" unless File.exist?(path)

        Browserctl::Bench.send(:remove_const, :CURRENT_TARGET) if Browserctl::Bench.const_defined?(:CURRENT_TARGET)
        load(path)
        Browserctl::Bench::CURRENT_TARGET
      end

      # Runs the target, writes a JSON result file, and returns the result.
      def run(target)
        result = target.run
        FileUtils.mkdir_p(RESULTS_DIR)
        File.write(File.join(RESULTS_DIR, "#{target.name}.json"), "#{JSON.pretty_generate(result)}\n")
        result
      end

      # One-line printable summary for a result hash.
      def format_row(result)
        format(
          "%<name>-20s runs=%<runs>d mean=%<mean>s p50=%<p50>s p95=%<p95>s p99=%<p99>s max=%<max>s",
          name: result[:name],
          runs: result[:runs],
          mean: fmt_ns(result[:mean_ns]),
          p50: fmt_ns(result[:p50_ns]),
          p95: fmt_ns(result[:p95_ns]),
          p99: fmt_ns(result[:p99_ns]),
          max: fmt_ns(result[:max_ns])
        )
      end

      def fmt_ns(nanos)
        if nanos >= 1_000_000
          format("%<v>.2fms", v: nanos / 1_000_000.0)
        elsif nanos >= 1_000
          format("%<v>.2fµs", v: nanos / 1_000.0)
        else
          "#{nanos}ns"
        end
      end
    end
  end
end

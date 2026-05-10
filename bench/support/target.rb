# frozen_string_literal: true

module Browserctl
  module Bench
    # A single benchmark target.
    #
    # `setup` is invoked once before measurement to allocate fixtures or other
    # state that must not be timed. It returns a context object that is then
    # passed to each `measure` invocation.
    #
    # `measure` is called repeatedly. Only the body of `measure` is timed,
    # using nanosecond-precision monotonic clock samples. We deliberately do
    # not depend on benchmark-ips: the harness is intentionally tiny so it
    # adds zero runtime dependencies and the math behind the numbers is
    # obvious from this file alone.
    BENCH_DEFAULT_ITERATIONS = 200
    BENCH_DEFAULT_WARMUP     = 20

    Target = Struct.new(:name, :setup, :measure, keyword_init: true) do
      # Runs the target and returns a result hash with summary statistics.
      #
      # @param iterations [Integer] number of timed samples to collect
      # @param warmup     [Integer] number of untimed samples run first
      def run(iterations: BENCH_DEFAULT_ITERATIONS, warmup: BENCH_DEFAULT_WARMUP)
        ctx = setup&.call

        warmup.times { measure.call(ctx) }

        samples = Array.new(iterations) do
          t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
          measure.call(ctx)
          Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t0
        end

        summarize(samples)
      end

      private

      def summarize(samples)
        sorted = samples.sort
        {
          name: name,
          runs: sorted.length,
          mean_ns: (sorted.sum.to_f / sorted.length).round,
          p50_ns: percentile(sorted, 0.50),
          p95_ns: percentile(sorted, 0.95),
          p99_ns: percentile(sorted, 0.99),
          max_ns: sorted.last
        }
      end

      def percentile(sorted, pct)
        return 0 if sorted.empty?

        # Nearest-rank percentile — simple and adequate for n in the hundreds.
        rank = (pct * sorted.length).ceil.clamp(1, sorted.length)
        sorted[rank - 1]
      end
    end
  end
end

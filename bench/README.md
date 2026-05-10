# bench/

Tiny, dependency-free performance harness for browserctl. The goal is to
catch order-of-magnitude regressions in code paths we care about — not to
publish marketing throughput numbers.

## Layout

    bench/
      README.md              ← this file
      budgets.yml            ← per-target p95 budgets (the contract)
      support/
        target.rb            ← Target struct + ns-precision sampler
        runner.rb            ← loads targets, writes JSON, prints rows
      targets/
        bundle_codec.rb      ← .bctl encode + decode round-trip
      results/               ← gitignored; written on each run

Each target file under `bench/targets/` assigns a `Browserctl::Bench::Target`
to `Browserctl::Bench::CURRENT_TARGET`. The runner loads files one at a time,
so targets do not interfere with each other.

## Running

    bundle exec rake bench:all                  # every target
    bundle exec rake "bench:run[bundle_codec]"  # one target

Each run writes `bench/results/<name>.json` with summary statistics:

    {
      "name": "bundle_codec",
      "runs": 200,
      "mean_ns": 38590,
      "p50_ns": 29000,
      "p95_ns": 52000,
      "p99_ns": 254000,
      "max_ns": 571000
    }

## How budgets are set

We deliberately keep the math obvious. After adding a target:

1. Run it five times back-to-back on a representative dev machine.
2. Take the **worst observed `p95_ns`** across those runs.
3. Multiply by `1.2` (a 20% headroom margin) and round up to a clean number.
4. Record both `budget_ns` and `observed_ns` in `bench/budgets.yml` so the
   next reviewer can see how much slack the budget has.

Budgets are intentionally generous on first add. Tightening them is fine
once the target has lived for a release or two and we know its variance.

## Why no benchmark-ips?

We measure with `Process.clock_gettime(:nanosecond)` directly, in roughly 30
lines of Ruby. That keeps the gem's runtime/dev-dep surface small and means
the numbers in `results/*.json` come from code that is read in one sitting.

## Enforcement

This harness writes results and budgets but does **not** yet fail the build
on a budget overrun. That gate lands as a follow-up PR.

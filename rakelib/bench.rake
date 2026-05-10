# frozen_string_literal: true

require_relative "../bench/support/runner"

namespace :bench do
  desc "Run every benchmark target and write results to bench/results/"
  task :all do
    Browserctl::Bench::Runner.all_targets.each do |name|
      target = Browserctl::Bench::Runner.load_target(name)
      result = Browserctl::Bench::Runner.run(target)
      puts Browserctl::Bench::Runner.format_row(result)
    end
  end

  desc "Run a single benchmark target by name (e.g. bench:run[bundle_codec])"
  task :run, [:name] do |_t, args|
    name = args[:name] or raise ArgumentError, "usage: rake 'bench:run[<name>]'"
    target = Browserctl::Bench::Runner.load_target(name)
    result = Browserctl::Bench::Runner.run(target)
    puts Browserctl::Bench::Runner.format_row(result)
  end
end

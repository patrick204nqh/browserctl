# frozen_string_literal: true

# Usage: HEADLESS=true bundle exec ruby spec/benchmarks/snapshot_bench.rb
#
# Measures snapshot latency and ping throughput against a live daemon.

require "benchmark"
require_relative "../../lib/browserctl"

ITERATIONS = 50
PAGE_NAME  = "bench"

client = Browserctl::Client.new
client.open_page(PAGE_NAME, url: "https://example.com")

puts "=== browserctl benchmark ==="
puts "Ruby #{RUBY_VERSION}, #{ITERATIONS} iterations each\n\n"

Benchmark.bm(20) do |x|
  x.report("ping:") do
    ITERATIONS.times { client.ping }
  end

  x.report("snapshot (ai):") do
    ITERATIONS.times { client.snapshot(PAGE_NAME, format: "ai") }
  end

  x.report("snapshot (html):") do
    ITERATIONS.times { client.snapshot(PAGE_NAME, format: "html") }
  end

  x.report("snapshot (diff):") do
    ITERATIONS.times { client.snapshot(PAGE_NAME, format: "ai", diff: true) }
  end
end

client.close_page(PAGE_NAME)
puts "\nDone."

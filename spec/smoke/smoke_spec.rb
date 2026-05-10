# frozen_string_literal: true

# Smoke specs — exercise stable public surfaces with a real Chrome.
#
# Excluded from the default suite via `.rspec` (`--tag ~smoke`). Run with:
#
#     bundle exec rspec --tag smoke
#
# Each spec:
#   * Loads a real public URL through a real Chrome/Chromium browser.
#   * Has a 30s wall-clock timeout (Timeout.timeout).
#   * On failure, dumps a minimal trace to tmp/smoke-trace.log + stderr.
#   * Skips cleanly (rather than failing) when Chrome is unavailable or the
#     network is offline — the nightly CI provides both, so a real failure
#     means real drift.
#
# Note: there is no browserctl GitHub Pages site at the time of writing
# (no docs/_config.yml, no gh-pages branch). The third stable surface here
# is github.com/patrick204nqh/browserctl, which is unlikely to drift in a
# way that breaks page-load + DOM access.

require "spec_helper"
require "fileutils"
require "timeout"
require "socket"

SMOKE_TRACE_PATH = File.expand_path("../../tmp/smoke-trace.log", __dir__)
SMOKE_TIMEOUT = 30

RSpec.describe "smoke", :smoke do
  def chrome_available?
    %w[chromium-browser google-chrome chromium chrome].any? do |b|
      system("which #{b}", out: File::NULL, err: File::NULL)
    end
  end

  def network_available?
    Socket.tcp("example.com", 80, connect_timeout: 3) { true }
  rescue StandardError
    false
  end

  def write_trace(label, error)
    FileUtils.mkdir_p(File.dirname(SMOKE_TRACE_PATH))
    File.open(SMOKE_TRACE_PATH, "a") do |f|
      f.puts "=== #{Time.now.utc.iso8601} #{label} ==="
      f.puts "#{error.class}: #{error.message}"
      f.puts(error.backtrace&.first(20))
      f.puts
    end
    warn "[smoke] failure trace -> #{SMOKE_TRACE_PATH}"
    warn "[smoke] #{error.class}: #{error.message}"
  end

  def visit_and_snapshot(url)
    @client.page_open("smoke", url: url)
    deadline = Time.now + SMOKE_TIMEOUT
    snap = nil
    loop do
      snap = @client.snapshot("smoke", format: "html")
      break if snap[:ok] && snap[:html]
      raise "snapshot timed out for #{url}" if Time.now > deadline

      sleep 0.2
    end
    snap
  ensure
    begin
      @client.page_close("smoke")
    rescue StandardError
      nil
    end
  end

  before(:all) do
    skip "Chrome not available — install chromium or google-chrome" unless chrome_available?
    skip "no network — smoke needs internet" unless network_available?

    @client = start_daemon
  end

  after(:all) do
    stop_daemon if @daemon_pid
  end

  around(:each) do |example|
    Timeout.timeout(SMOKE_TIMEOUT) { example.run }
  rescue StandardError => e
    write_trace(example.full_description, e)
    raise
  end

  it "loads example.com and renders the canonical title" do
    snap = visit_and_snapshot("https://example.com/")
    expect(snap[:html]).to include("Example")
    title = @client.evaluate("smoke", "document.title")
    expect(title[:result].to_s).to match(/Example/i)
  end

  it "loads the browserctl GitHub repo page" do
    snap = visit_and_snapshot("https://github.com/patrick204nqh/browserctl")
    expect(snap[:html]).to include("browserctl")
  end

  # Third stable surface: a known browserctl-adjacent URL we control or
  # trust to be long-lived. Skipped because no GitHub Pages site exists yet
  # for this repo. Re-enable once docs/ ships as Pages.
  it "loads the browserctl docs site (skipped: no GH Pages site yet)" do
    skip "no GitHub Pages site configured for this repo"
  end
end

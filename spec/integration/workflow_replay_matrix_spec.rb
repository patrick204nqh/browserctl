# frozen_string_literal: true

require "spec_helper"
require "browserctl/driver"

# Cross-browser replay matrix.
#
# Picks the browser indicated by BROWSERCTL_BROWSER (chrome|chromium|brave),
# starts a daemon backed by that binary, and replays a couple of representative
# workflow shapes (form-fill + JS evaluate) end-to-end against data: URLs.
#
# Skips cleanly when the requested browser is not installed locally — never
# fails the dev's local `rspec` run. CI provides each binary in its own matrix
# cell.
module ReplayMatrixHelpers
  BINS = {
    "chrome" => %w[google-chrome chrome],
    "chromium" => %w[chromium-browser chromium],
    "brave" => %w[brave-browser brave]
  }.freeze

  ENV_OVERRIDES = { "chromium" => "CHROMIUM_PATH", "brave" => "BRAVE_PATH" }.freeze

  module_function

  def selected_browser
    ENV.fetch("BROWSERCTL_BROWSER", "chrome")
  end

  def browser_available?(name)
    if (env = ENV_OVERRIDES[name])
      override = ENV.fetch(env, nil)
      return true if override && File.executable?(override)
    end
    return true if BINS.fetch(name, []).any? { |b| system("which #{b}", out: File::NULL, err: File::NULL) }
    return Browserctl::Driver::CDP::BRAVE_PATHS.values.flatten.any? { |p| File.executable?(p) } \
      if name == "brave"

    false
  end
end

RSpec.describe "workflow replay matrix", :integration do
  def self.selected_browser
    ReplayMatrixHelpers.selected_browser
  end

  def browser_available?(name)
    ReplayMatrixHelpers.browser_available?(name)
  end

  before(:all) do
    browser = self.class.selected_browser
    skip "#{browser} not installed (set BROWSERCTL_BROWSER or install the binary)" \
      unless browser_available?(browser)

    @client = start_daemon(browser: browser)
  end

  after(:all) { stop_daemon if @daemon_pid }

  it "replays a form-fill + click workflow on #{selected_browser}" do
    html = <<~HTML
      <html><body>
        <input id="email" type="text">
        <input id="password" type="password">
        <button id="go" onclick="document.body.dataset.signed='1'">Sign in</button>
      </body></html>
    HTML
    encoded = "data:text/html;base64,#{[html].pack('m0')}"

    @client.page_open("login")
    @client.navigate("login", encoded)
    expect(@client.fill("login", "input#email", "alice@example.com")[:ok]).to be(true)
    expect(@client.fill("login", "input#password", "hunter2")[:ok]).to be(true)
    expect(@client.click("login", "button#go")[:ok]).to be(true)
    expect(@client.evaluate("login", "document.body.dataset.signed")[:result]).to eq("1")
  ensure
    begin
      @client.page_close("login")
    rescue StandardError
      nil
    end
  end

  it "replays a JS-evaluate + snapshot workflow on #{selected_browser}" do
    html = "<html><body><a href='/'>Home</a><button id='b'>Click</button></body></html>"
    encoded = "data:text/html;base64,#{[html].pack('m0')}"

    @client.page_open("eval")
    @client.navigate("eval", encoded)
    expect(@client.evaluate("eval", "1 + 2")[:result]).to eq(3)
    snap = @client.snapshot("eval", format: "elements")
    expect(snap[:ok]).to be(true)
    expect(snap[:snapshot]).to be_an(Array)
    expect(snap[:snapshot].map { |e| e[:tag] }).to include("a", "button")
  ensure
    begin
      @client.page_close("eval")
    rescue StandardError
      nil
    end
  end
end

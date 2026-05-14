# frozen_string_literal: true

require "spec_helper"

# Regression test for v0.15 WS-2 PR 5. Plugins registered via
# `Browserctl.register_command` used to run inline on the daemon thread with
# no timeout and no rescue boundary — a buggy third-party plugin could
# either hang the daemon or take it down with an uncaught exception.
#
# After PR 5 every plugin invocation is wrapped by
# `Browserctl::PluginDispatcher`:
#
# - Uncaught exceptions are converted into a typed `PLUGIN_FAILED` JSON-RPC
#   response carrying the plugin name in `context.plugin`.
# - The per-plugin timeout (default 30s, configurable via `timeout:` on
#   `register_command`, opt-out with `timeout: nil`) elapses into a typed
#   `PLUGIN_TIMED_OUT` response. The daemon stays answering subsequent
#   commands; a follow-up `page list` returns in well under a second.
RSpec.describe "plugin command isolation", :integration do
  before(:all) do
    Browserctl.register_command(:plugin_raises) do |_session, _req|
      raise "boom from plugin"
    end

    Browserctl.register_command(:plugin_hangs, timeout: 1) do |_session, _req|
      sleep 60
      { ok: true }
    end

    Browserctl.register_command(:plugin_malformed) do |_session, _req|
      # Returning something the daemon's JSON serialiser can't encode forces
      # the rescue boundary to convert the downstream failure into a typed
      # PLUGIN_FAILED response.
      obj = Object.new
      def obj.to_json(*) = raise "cannot encode"
      { ok: true, payload: obj }
    end

    @client = start_daemon
    @client.page_open("p", url: "about:blank")
  end

  after(:all) do
    stop_daemon
    Browserctl.instance_variable_set(:@plugin_commands, {})
  end

  it "converts a raising plugin into PLUGIN_FAILED with the plugin name in context" do
    res = @client.call("plugin_raises", name: "p")
    expect(res[:code]).to eq(Browserctl::Error::Codes::PLUGIN_FAILED)
    expect(res[:error]).to include("plugin_raises")
    expect(res[:context][:plugin]).to eq("plugin_raises")
  end

  it "converts a hanging plugin into PLUGIN_TIMED_OUT and keeps the daemon responsive" do
    res = @client.call("plugin_hangs", name: "p")
    expect(res[:code]).to eq(Browserctl::Error::Codes::PLUGIN_TIMED_OUT)
    expect(res[:context][:plugin]).to eq("plugin_hangs")
    expect(res[:context][:timeout]).to eq(1)

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    pages   = @client.page_list
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    expect(pages[:pages]).to include(hash_including(name: "p"))
    expect(elapsed).to be < 1.0
  end

  it "converts a plugin returning unencodable data into PLUGIN_FAILED" do
    res = @client.call("plugin_malformed", name: "p")
    expect(res[:code]).to eq(Browserctl::Error::Codes::PLUGIN_FAILED)
    expect(res[:context][:plugin]).to eq("plugin_malformed")
  end
end

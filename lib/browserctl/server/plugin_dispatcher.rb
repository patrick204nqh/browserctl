# frozen_string_literal: true

require "json"
require "timeout"
require_relative "handlers/error_payload"
require_relative "../errors"

module Browserctl
  # Invokes plugin commands registered via {Browserctl.register_command} from
  # the daemon's command-dispatch loop. Extracted from `CommandDispatcher` in
  # v0.15 WS-2 PR 5 so plugin invocation gets two daemon-protecting
  # properties:
  #
  # - A per-plugin wall-clock timeout (default
  #   {Browserctl::DEFAULT_PLUGIN_TIMEOUT}, configurable via `timeout:` on
  #   `register_command`, opt-out with `timeout: nil`). On expiry the
  #   dispatcher returns a typed `PLUGIN_TIMED_OUT` response and the daemon
  #   stays answering subsequent commands.
  # - A rescue boundary that converts ANY uncaught exception from the plugin
  #   block into a typed `PLUGIN_FAILED` JSON-RPC response. The plugin name
  #   is always present in the response's `context` so agents can branch on
  #   it. The daemon process is never taken down by a buggy plugin.
  #
  # Plugins live in the Extension zone (see
  # `docs/reference/api-stability.md`); the response shape here is documented
  # in `docs/reference/errors.md`.
  class PluginDispatcher
    include CommandDispatcher::Handlers::ErrorPayload

    # @param pages [Hash{String => PageSession}] shared daemon page registry
    # @param global_mutex [Mutex] mutex guarding the page registry
    def initialize(pages, global_mutex:)
      @pages        = pages
      @global_mutex = global_mutex
    end

    # Looks up the plugin command for `req[:cmd]` and invokes it under the
    # timeout / rescue boundary. Returns `nil` if no plugin handles this
    # command — the caller falls through to its "unknown command" branch.
    #
    # @param req [Hash{Symbol => Object}] parsed request
    # @return [Hash{Symbol => Object}, nil]
    def dispatch(req)
      plugin = Browserctl.lookup_plugin_command(req[:cmd])
      return nil unless plugin

      name    = req[:cmd].to_s
      session = req[:name] ? @global_mutex.synchronize { @pages[req[:name]] } : nil

      Browserctl.logger.debug("plugin:#{name} #{req[:name]}")
      invoke(plugin, name, session, req)
    end

    private

    def invoke(plugin, name, session, req)
      response = if plugin.timeout
                   Timeout.timeout(plugin.timeout) { plugin.block.call(session, req) }
                 else
                   plugin.block.call(session, req)
                 end
      # Verify the response will survive the daemon's JSON serialiser. A plugin
      # that returns an unencodable object would otherwise blow up at the
      # socket-write step, outside this rescue boundary.
      JSON.generate(response)
      response
    rescue Timeout::Error
      Browserctl.logger.warn("plugin:#{name} timed out after #{plugin.timeout}s")
      error_payload(
        code: Browserctl::Error::Codes::PLUGIN_TIMED_OUT,
        message: "plugin '#{name}' timed out after #{plugin.timeout}s",
        context: { plugin: name, timeout: plugin.timeout }
      )
    rescue StandardError, ScriptError => e
      Browserctl.logger.warn("plugin:#{name} raised #{e.class}: #{e.message}")
      error_payload(
        code: Browserctl::Error::Codes::PLUGIN_FAILED,
        message: "plugin '#{name}' failed: #{e.class}: #{e.message}",
        context: { plugin: name, exception: e.class.name }
      )
    end
  end
end

# frozen_string_literal: true

require_relative "browserctl/version"
require_relative "browserctl/constants"
require_relative "browserctl/errors"
require_relative "browserctl/secret_resolvers"
require_relative "browserctl/tracing"
require_relative "browserctl/workflow"
require_relative "browserctl/runner"
require_relative "browserctl/client"

module Browserctl
  # Default per-plugin command timeout (seconds). Plugins registered via
  # {register_command} without an explicit `timeout:` are wrapped in this
  # cap by `Browserctl::PluginDispatcher`. Pass `timeout: nil` on
  # `register_command` to opt out (not recommended — a runaway plugin will
  # hold the daemon's command thread until the process is restarted).
  DEFAULT_PLUGIN_TIMEOUT = 30

  # Value object carried by the plugin registry. `block` is the plugin's
  # `(session, req) -> response` callable; `timeout` is the per-command wall
  # clock in seconds (or `nil` for no timeout).
  PluginCommand = Struct.new(:block, :timeout, keyword_init: true)

  @plugin_commands_mutex = Mutex.new
  @plugin_commands = {}

  # Registers a plugin command callable under `name`. The block receives
  # `(session, req)` and must return a JSON-RPC-shaped Hash. The daemon wraps
  # every invocation in a per-plugin timeout (default
  # {DEFAULT_PLUGIN_TIMEOUT}) and a rescue boundary that converts any
  # uncaught exception into a typed `PLUGIN_FAILED` response without taking
  # down the daemon — see {Browserctl::PluginDispatcher}.
  #
  # @param name [String, Symbol] command verb on the wire
  # @param timeout [Numeric, nil] per-invocation timeout in seconds;
  #   `nil` opts out of the timeout entirely. Defaults to
  #   {DEFAULT_PLUGIN_TIMEOUT}.
  def self.register_command(name, timeout: DEFAULT_PLUGIN_TIMEOUT, &block)
    @plugin_commands_mutex.synchronize do
      @plugin_commands[name.to_s] = PluginCommand.new(block: block, timeout: timeout)
    end
  end

  def self.lookup_plugin_command(name)
    @plugin_commands_mutex.synchronize { @plugin_commands[name.to_s] }
  end

  def self.plugin_commands_snapshot
    @plugin_commands_mutex.synchronize { @plugin_commands.dup }
  end
end

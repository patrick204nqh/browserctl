# frozen_string_literal: true

require_relative "browserctl/version"
require_relative "browserctl/constants"
require_relative "browserctl/errors"
require_relative "browserctl/workflow"
require_relative "browserctl/runner"
require_relative "browserctl/client"

module Browserctl
  @plugin_commands_mutex = Mutex.new
  @plugin_commands = {}

  def self.register_command(name, &block)
    @plugin_commands_mutex.synchronize { @plugin_commands[name.to_s] = block }
  end

  def self.lookup_plugin_command(name)
    @plugin_commands_mutex.synchronize { @plugin_commands[name.to_s] }
  end

  def self.plugin_commands_snapshot
    @plugin_commands_mutex.synchronize { @plugin_commands.dup }
  end
end

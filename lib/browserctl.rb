# frozen_string_literal: true

require_relative "browserctl/version"
require_relative "browserctl/constants"
require_relative "browserctl/workflow"
require_relative "browserctl/runner"
require_relative "browserctl/client"

module Browserctl
  PLUGIN_COMMANDS = {} # rubocop:disable Style/MutableConstant

  def self.register_command(name, &block)
    PLUGIN_COMMANDS[name.to_s] = block
  end
end

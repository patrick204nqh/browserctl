# frozen_string_literal: true

require_relative "cli_output"

module Browserctl
  module Commands
    module Pause
      extend CliOutput

      def self.run(client, args)
        name = args.shift or abort "usage: browserctl pause <page>"
        res = client.pause(name)
        if res[:error]
          warn "Error: #{res[:error]}"
          exit 1
        end
        puts "Page '#{name}' paused. Browser is live — interact freely."
        puts "When done: browserctl resume #{name}"
      end
    end
  end
end

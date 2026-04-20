# frozen_string_literal: true

require_relative "cli_output"

module Browserctl
  module Commands
    module PauseResume
      extend CliOutput

      def self.pause(client, args)
        name = args.shift or abort "usage: browserctl pause <page>"
        res = client.pause(name)
        if res[:error]
          warn "Error: #{res[:error]}"
          exit 1
        end
        puts "Page '#{name}' paused. Browser is live — interact freely."
        puts "When done: browserctl resume #{name}"
      end

      def self.resume(client, args)
        name = args.shift or abort "usage: browserctl resume <page>"
        res = client.resume(name)
        if res[:error]
          warn "Error: #{res[:error]}"
          exit 1
        end
        puts "Page '#{name}' resumed."
      end
    end
  end
end

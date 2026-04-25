# frozen_string_literal: true

require_relative "cli_output"

module Browserctl
  module Commands
    module Resume
      extend CliOutput

      def self.run(client, args)
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

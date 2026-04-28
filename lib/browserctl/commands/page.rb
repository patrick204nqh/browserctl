# frozen_string_literal: true

require "optimist"
require_relative "cli_output"

module Browserctl
  module Commands
    module Page
      extend CliOutput

      USAGE = "Usage: browserctl page <open|close|list|focus> [args]"

      def self.run(client, args)
        sub = args.shift or abort USAGE
        case sub
        when "open"  then run_open(client, args)
        when "close" then run_close(client, args)
        when "list"  then run_list(client)
        when "focus" then run_focus(client, args)
        else abort "unknown page subcommand '#{sub}'\n#{USAGE}"
        end
      end

      def self.run_open(client, args)
        opts = Optimist.options(args) do
          opt :url, "URL to navigate to", type: :string, short: "-u"
        end
        name = args.shift or abort "usage: browserctl page open <name> [--url URL]"
        print_result(client.page_open(name, url: opts[:url]))
      end

      def self.run_close(client, args)
        name = args.shift or abort "usage: browserctl page close <name>"
        print_result(client.page_close(name))
      end

      def self.run_list(client)
        print_result(client.page_list)
      end

      def self.run_focus(client, args)
        name = args.shift or abort "usage: browserctl page focus <name>"
        print_result(client.call("page_focus", name: name))
      end
    end
  end
end

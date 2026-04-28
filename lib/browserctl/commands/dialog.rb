# frozen_string_literal: true

require_relative "cli_output"

module Browserctl
  module Commands
    module Dialog
      extend CliOutput

      USAGE = "Usage: browserctl dialog <accept|dismiss> <page> [text]"

      def self.run(client, args)
        sub = args.shift or abort USAGE
        case sub
        when "accept"  then run_accept(client, args)
        when "dismiss" then run_dismiss(client, args)
        else abort "unknown dialog subcommand '#{sub}'\n#{USAGE}"
        end
      end

      def self.run_accept(client, args)
        name = args.shift or abort "usage: browserctl dialog accept <page> [text]"
        text = args.shift
        print_result(client.dialog_accept(name, text: text))
      end

      def self.run_dismiss(client, args)
        name = args.shift or abort "usage: browserctl dialog dismiss <page>"
        print_result(client.dialog_dismiss(name))
      end
    end
  end
end

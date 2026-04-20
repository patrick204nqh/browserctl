# frozen_string_literal: true

require "fileutils"
require "optimist"
require "browserctl/recording"

module Browserctl
  module Commands
    class Record
      USAGE = "Usage: browserctl record start <name> | stop [--out PATH] | status"

      def self.run(args)
        subcmd = args.shift
        case subcmd
        when "start"  then run_start(args)
        when "stop"   then run_stop(args)
        when "status" then run_status
        else
          abort "#{USAGE}\nRun 'browserctl record <subcommand> --help' for details."
        end
      end

      class << self
        private

        def run_start(args)
          Optimist.options(args) { banner "Usage: browserctl record start <name>" }
          name = args.shift or abort "usage: browserctl record start <name>"
          Recording.start(name)
          puts "Recording started: #{name}"
          puts "Run browser commands, then: browserctl record stop"
        end

        def run_stop(args)
          opts = Optimist.options(args) do
            banner "Usage: browserctl record stop [--out PATH]"
            opt :out, "Output path for workflow file", type: :string, short: "-o"
          end
          name = Recording.stop
          out  = opts[:out] || File.join(".browserctl/workflows", "#{name}.rb")
          FileUtils.mkdir_p(File.dirname(out))
          Recording.generate_workflow(name, output_path: out)
          puts "Workflow saved: #{out}"
          puts "Run with: browserctl run #{name}"
        end

        def run_status
          active = Recording.active
          puts active ? "Active recording: #{active}" : "No active recording."
        end
      end
    end
  end
end

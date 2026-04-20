# frozen_string_literal: true

require "fileutils"
require "browserctl/recording"

module Browserctl
  module Commands
    class Record
      USAGE = "usage: browserctl record start <name> | stop | status | generate <name> [--out path]"

      def self.run(args)
        subcmd = args.shift
        case subcmd
        when "start"    then run_start(args)
        when "stop"     then run_stop
        when "generate" then run_generate(args)
        when "status"   then run_status
        else                 abort USAGE
        end
      end

      class << self
        private

        def run_start(args)
          name = args.shift or abort "usage: browserctl record start <name>"
          Recording.start(name)
          puts "Recording started: #{name}"
          puts "Run browser commands, then: browserctl record stop"
        end

        def run_stop
          name      = Recording.stop
          dest_dir  = ".browserctl/workflows"
          dest_file = File.join(dest_dir, "#{name}.rb")
          FileUtils.mkdir_p(dest_dir)
          Recording.generate_workflow(name, output_path: dest_file)
          puts "Workflow saved: #{dest_file}"
          puts "Run with: browserctl run #{name}"
        end

        def run_generate(args)
          name = args.shift or abort "usage: browserctl record generate <name> [--out path]"
          idx  = args.index("--out")
          out  = idx && args.delete_at(idx + 1).tap { args.delete_at(idx) }
          ruby = Recording.generate_workflow(name, output_path: out)
          out ? puts("Workflow saved: #{out}") : puts(ruby)
        end

        def run_status
          active = Recording.active
          puts active ? "Active recording: #{active}" : "No active recording."
        end
      end
    end
  end
end

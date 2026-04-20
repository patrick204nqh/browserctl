# frozen_string_literal: true

require "fileutils"
require "browserctl/recording"

module Browserctl
  module Commands
    class Record
      def self.run(args)
        subcmd = args.shift
        case subcmd
        when "start"
          name = args.shift or abort "usage: browserctl record start <name>"
          Recording.start(name)
          puts "Recording started: #{name}"
          puts "Run browser commands, then: browserctl record stop"
        when "stop"
          name      = Recording.stop
          dest_dir  = ".browserctl/workflows"
          dest_file = File.join(dest_dir, "#{name}.rb")
          FileUtils.mkdir_p(dest_dir)
          Recording.generate_workflow(name, output_path: dest_file)
          puts "Workflow saved: #{dest_file}"
          puts "Run with: browserctl run #{name}"
        when "status"
          active = Recording.active
          puts active ? "Active recording: #{active}" : "No active recording."
        else
          abort "usage: browserctl record start <name> | stop | status"
        end
      end
    end
  end
end

# frozen_string_literal: true

require "fileutils"
require "browserctl/recording"

module Browserctl
  module Commands
    class Record
      USAGE = "usage: browserctl record start <name> | stop [--out path] | status"

      def self.run(args)
        subcmd = args.shift
        case subcmd
        when "start"  then run_start(args)
        when "stop"   then run_stop(args)
        when "status" then run_status
        else               abort USAGE
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

        def run_stop(args)
          idx = args.index("--out")
          out = if idx
                  args.delete_at(idx)
                  args.delete_at(idx)
                end
          name = Recording.stop
          if out
            FileUtils.mkdir_p(File.dirname(out))
            Recording.generate_workflow(name, output_path: out)
            puts "Workflow saved: #{out}"
          else
            dest_dir  = ".browserctl/workflows"
            dest_file = File.join(dest_dir, "#{name}.rb")
            FileUtils.mkdir_p(dest_dir)
            Recording.generate_workflow(name, output_path: dest_file)
            puts "Workflow saved: #{dest_file}"
          end
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

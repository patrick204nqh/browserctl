# frozen_string_literal: true

require "fileutils"
require "json"
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
          abort "Invalid recording name #{name.inspect} — use only letters, digits, _ or -" \
            unless name =~ /\A[a-zA-Z0-9_-]{1,64}\z/
          Recording.start(name)
          puts JSON.generate({ ok: true, name: name })
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
          puts JSON.generate({ ok: true, name: name, path: out })
        end

        def run_status
          active = Recording.active
          puts JSON.generate({ active: active })
        end
      end
    end
  end
end

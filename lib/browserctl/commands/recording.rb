# frozen_string_literal: true

require "fileutils"
require "json"
require "optimist"
require "browserctl/recording"

module Browserctl
  module Commands
    class Recording
      USAGE = "Usage: browserctl recording start <name> | stop [--out PATH] | status"

      def self.run(args)
        subcmd = args.shift
        case subcmd
        when "start"  then run_start(args)
        when "stop"   then run_stop(args)
        when "status" then run_status
        else
          abort "#{USAGE}\nRun 'browserctl recording <subcommand> --help' for details."
        end
      end

      class << self
        private

        def run_start(args)
          Optimist.options(args) { banner "Usage: browserctl recording start <name>" }
          name = args.shift or abort "usage: browserctl recording start <name>"
          abort "Invalid recording name #{name.inspect} — use only letters, digits, _ or -" \
            unless name =~ /\A[a-zA-Z0-9_-]{1,64}\z/
          Browserctl::Recording.start(name)
          puts JSON.generate({ ok: true, name: name })
        end

        def run_stop(args)
          opts = Optimist.options(args) do
            banner "Usage: browserctl recording stop [--out PATH]"
            opt :out, "Output path for workflow file", type: :string, short: "-o"
          end
          name = Browserctl::Recording.stop
          out  = opts[:out] || File.join(".browserctl/workflows", "#{name}.rb")
          FileUtils.mkdir_p(File.dirname(out))
          Browserctl::Recording.generate_workflow(name, output_path: out)
          puts JSON.generate({ ok: true, name: name, path: out })
        end

        def run_status
          active = Browserctl::Recording.active
          puts JSON.generate({ active: active })
        end
      end
    end
  end
end

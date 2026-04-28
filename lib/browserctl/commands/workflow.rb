# frozen_string_literal: true

require_relative "cli_output"

module Browserctl
  module Commands
    module Workflow
      extend CliOutput

      USAGE = "Usage: browserctl workflow <run|list|describe> [args]"

      def self.run(runner, args)
        sub = args.shift or abort USAGE
        case sub
        when "run"      then run_workflow(runner, args)
        when "list"     then run_list(runner)
        when "describe" then run_describe(runner, args)
        else abort "unknown workflow subcommand '#{sub}'\n#{USAGE}"
        end
      end

      def self.run_workflow(runner, args)
        name = args.shift or abort "usage: browserctl workflow run <name|file> [--params file] [--key value ...]"
        if File.exist?(name)
          before = Browserctl.registry_snapshot.keys
          load File.expand_path(name)
          name = (Browserctl.registry_snapshot.keys - before).first || File.basename(name, ".rb")
        end

        params_file_idx = args.index("--params")
        file_params = {}
        if params_file_idx
          params_path = args.delete_at(params_file_idx + 1)
          args.delete_at(params_file_idx)
          begin
            file_params = Browserctl::Runner.load_params_file(params_path)
          rescue StandardError => e
            abort "Error loading params file: #{e.message}"
          end
        end

        cli_params = {}
        args.each_slice(2) do |flag, val|
          key = flag.sub(/\A--/, "").to_sym
          cli_params[key] = val
        end

        params = file_params.merge(cli_params)
        success = runner.run_workflow(name, **params)
        exit(success ? 0 : 1)
      end

      def self.run_list(runner)
        list = runner.list_workflows
        list.each { |w| puts "#{w[:name].ljust(24)} #{w[:desc]}" }
      end

      def self.run_describe(runner, args)
        name = args.shift or abort "usage: browserctl workflow describe <name>"
        puts JSON.pretty_generate(runner.describe_workflow(name))
      end
    end
  end
end

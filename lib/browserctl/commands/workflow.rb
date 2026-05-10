# frozen_string_literal: true

require "json"
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

      EXIT_CODE = { clean: 0, drift: 2, fail: 1 }.freeze

      def self.run_workflow(runner, args)
        name = args.shift or abort \
          "usage: browserctl workflow run <name|file> [--check] [--params file] [--key value ...]"
        if File.exist?(name)
          before = Browserctl.registry_snapshot.keys
          load File.expand_path(name)
          name = (Browserctl.registry_snapshot.keys - before).first || File.basename(name, ".rb")
        end

        check = !args.delete("--check").nil?

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
        verdict = runner.run_workflow(name, check: check, **params)
        exit(EXIT_CODE.fetch(verdict, 1))
      end

      def self.run_list(runner)
        list = runner.list_workflows
        puts JSON.generate({ workflows: list.map { |w| { name: w[:name], desc: w[:desc] } } })
      end

      def self.run_describe(runner, args)
        name = args.shift or abort "usage: browserctl workflow describe <name>"
        puts JSON.pretty_generate(runner.describe_workflow(name))
      end
    end
  end
end

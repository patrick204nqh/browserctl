# frozen_string_literal: true

require "json"
require_relative "cli_output"
require_relative "../flow_registry"
require_relative "../runner"

module Browserctl
  module Commands
    module Flow
      extend CliOutput

      USAGE = "Usage: browserctl flow <run|list|describe> [args]"

      def self.run(client, args)
        sub = args.shift or abort USAGE
        case sub
        when "run"      then run_flow(client, args)
        when "list"     then run_list
        when "describe" then run_describe(args)
        else abort "unknown flow subcommand '#{sub}'\n#{USAGE}"
        end
      end

      def self.run_flow(client, args)
        name = args.shift or
          abort "usage: browserctl flow run <name|file> [--page NAME] [--params FILE] [--key value ...]"

        flow = resolve(name)
        page_name, params = parse_run_args(args)
        page_proxy = page_name ? Browserctl::PageProxy.new(page_name, client) : nil

        result = flow.run(page: page_proxy, client: client, **params)
        puts JSON.generate(ok: true, flow: flow.name, result: serialisable(result))
      rescue Browserctl::FlowError => e
        warn "Error: #{e.message}"
        puts JSON.generate(ok: false, code: e.code, error: e.message)
        exit 1
      end

      def self.run_list
        entries = Browserctl::FlowRegistry.list
        puts JSON.generate(flows: entries)
      end

      def self.run_describe(args)
        name = args.shift or abort "usage: browserctl flow describe <name>"
        flow = resolve(name)
        puts JSON.pretty_generate(
          name: flow.name,
          desc: flow.description,
          version: flow.version_string,
          requires_browserctl: flow.min_browserctl_version,
          params: format_params(flow),
          preconditions: flow.preconditions.map(&:label),
          steps: flow.steps.map(&:label),
          postconditions: flow.postconditions.map(&:label),
          produces_state: !flow.produces_state_block.nil?
        )
      end

      def self.resolve(name_or_path)
        if File.exist?(name_or_path)
          before = Browserctl.flow_registry_snapshot.keys
          load File.expand_path(name_or_path)
          new_name = (Browserctl.flow_registry_snapshot.keys - before).first
          new_name ||= File.basename(name_or_path, ".rb")
          flow = Browserctl.lookup_flow(new_name)
        else
          flow = Browserctl::FlowRegistry.resolve(name_or_path)
        end
        flow or abort "flow '#{name_or_path}' not found"
      end

      def self.parse_run_args(args)
        page_name = take_option(args, "--page")
        params_path = take_option(args, "--params")
        file_params = params_path ? load_params_file(params_path) : {}
        cli_params = pair_args(args)
        [page_name, file_params.merge(cli_params)]
      end

      def self.take_option(args, flag)
        idx = args.index(flag)
        return nil unless idx

        value = args.delete_at(idx + 1)
        args.delete_at(idx)
        value
      end

      def self.load_params_file(path)
        Browserctl::Runner.load_params_file(path)
      rescue StandardError => e
        abort "Error loading params file: #{e.message}"
      end

      def self.pair_args(args)
        out = {}
        args.each_slice(2) do |flag, val|
          out[flag.sub(/\A--/, "").to_sym] = val
        end
        out
      end

      def self.format_params(flow)
        flow.param_defs.transform_values do |p|
          entry = { required: p.required, secret: p.secret, default: p.default }
          entry[:secret_ref] = p.secret_ref if p.secret_ref
          entry
        end
      end

      def self.serialisable(value)
        case value
        when nil, true, false, Numeric, String, Hash, Array then value
        when Symbol then value.to_s
        else value.respond_to?(:to_h) ? value.to_h : value.to_s
        end
      end
    end
  end
end

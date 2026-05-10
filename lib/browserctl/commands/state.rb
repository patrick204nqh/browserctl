# frozen_string_literal: true

require "io/console"
require "json"
require_relative "cli_output"
require_relative "output_format"

module Browserctl
  module Commands
    # `browserctl state` — top-level command for portable, encrypted, origin-
    # scoped browser state. Wraps the daemon's state_* RPCs.
    module State
      extend CliOutput

      USAGE = "Usage: browserctl state <save|load|list|info|delete|rotate|export|import> [args]"

      DAEMON_SUBCOMMANDS = {
        "save" => :run_save, "load" => :run_load, "list" => :run_list,
        "info" => :run_info, "delete" => :run_delete, "rotate" => :run_rotate
      }.freeze

      LOCAL_SUBCOMMANDS = { "export" => :run_export, "import" => :run_import }.freeze

      def self.run(client, args)
        sub = args.shift or abort USAGE

        if (m = DAEMON_SUBCOMMANDS[sub])
          sub == "list" ? send(m, client) : send(m, client, args)
        elsif (m = LOCAL_SUBCOMMANDS[sub])
          send(m, args)
        else
          abort "unknown state subcommand '#{sub}'\n#{USAGE}"
        end
      end

      def self.run_save(client, args)
        encrypt = args.delete("--encrypt")
        origins = extract_value!(args, "--origins")
        flow    = extract_value!(args, "--flow")
        name    = args.shift or abort "usage: browserctl state save <name> [--encrypt] " \
                                      "[--origins a,b] [--flow NAME]"

        passphrase = encrypt ? prompt_passphrase(confirm: true) : nil
        origin_list = parse_origins(origins)

        print_result(client.state_save(name, origins: origin_list, flow: flow, passphrase: passphrase))
      end

      def self.parse_origins(value)
        return nil unless value

        value.split(",").map(&:strip).reject(&:empty?)
      end

      def self.run_load(client, args)
        name = args.shift or abort "usage: browserctl state load <name>"
        passphrase = state_needs_passphrase?(client, name) ? prompt_passphrase : nil
        print_result(client.state_load(name, passphrase: passphrase))
      end

      def self.run_list(client)
        print_result(client.state_list)
      end

      def self.run_info(client, args)
        name = args.shift or abort "usage: browserctl state info <name>"
        print_result(client.state_info(name))
      end

      def self.run_delete(client, args)
        name = args.shift or abort "usage: browserctl state delete <name>"
        print_result(client.state_delete(name))
      end

      # Re-runs the flow bound to <name> and re-saves the bundle. The flow is
      # read from the manifest (set when the bundle was originally produced
      # via `state save --flow ...`). Params come from --params or k=v pairs.
      def self.run_rotate(client, args)
        require "browserctl/flow_registry"
        page_name   = extract_value!(args, "--page")
        params_path = extract_value!(args, "--params")
        name        = args.shift or abort "usage: browserctl state rotate <name> " \
                                          "[--page NAME] [--params FILE] [--key value ...]"

        manifest = read_manifest!(client, name)
        flow     = resolve_bound_flow!(manifest)
        params   = build_rotate_params(params_path, args)
        page_proxy = page_name ? Browserctl::PageProxy.new(page_name, client) : nil

        flow.run(page: page_proxy, client: client, **params)

        save_result = client.state_save(name,
                                        flow: flow.name,
                                        flow_version: flow.version_string,
                                        origins: manifest[:origins])
        print_result(save_result.merge(rotated_flow: flow.name))
      rescue Browserctl::FlowError => e
        warn "Error: #{e.message}"
        exit 1
      end

      def self.read_manifest!(client, name)
        info = client.state_info(name)
        abort "Error: #{info[:error] || info['error']}" if info[:error] || info["error"]

        info[:info] || info["info"] || {}
      end
      private_class_method :read_manifest!

      def self.resolve_bound_flow!(manifest)
        flow_name = manifest[:flow] || manifest["flow"]
        abort "Error: state has no bound flow — re-save with `state save --flow NAME` first" if flow_name.nil? ||
                                                                                                flow_name.to_s.empty?

        flow = Browserctl::FlowRegistry.resolve(flow_name)
        abort "Error: flow '#{flow_name}' not found in registry" unless flow

        flow
      end
      private_class_method :resolve_bound_flow!

      def self.build_rotate_params(params_path, args)
        require "browserctl/runner"
        file_params = params_path ? Browserctl::Runner.load_params_file(params_path) : {}
        cli_params  = args.each_slice(2).to_h { |flag, val| [flag.to_s.sub(/\A--/, "").to_sym, val] }
        file_params.merge(cli_params)
      end
      private_class_method :build_rotate_params

      def self.run_export(args)
        name        = args.shift or abort "usage: browserctl state export <name> <destination>"
        destination = args.shift or abort "usage: browserctl state export <name> <destination>"
        require "browserctl/state"
        result = Browserctl::State.export(name, destination)
        OutputFormat.current.emit(result)
      rescue Browserctl::State::Transport::TransportError, Browserctl::Error, ArgumentError => e
        warn "Error: #{e.message}"
        exit 1
      end

      def self.run_import(args)
        name_override = extract_value!(args, "--name")
        source        = args.shift or abort "usage: browserctl state import <source> [--name NAME]"
        require "browserctl/state"
        result = Browserctl::State.import(source, name: name_override)
        OutputFormat.current.emit(result)
      rescue Browserctl::State::Transport::TransportError,
             Browserctl::State::Bundle::BundleError,
             Browserctl::Error, ArgumentError => e
        warn "Error: #{e.message}"
        exit 1
      end

      private_class_method :parse_origins

      def self.extract_value!(args, flag)
        idx = args.index(flag)
        return nil unless idx

        args.delete_at(idx)
        args.delete_at(idx) or abort "missing value for #{flag}"
      end
      private_class_method :extract_value!

      def self.prompt_passphrase(confirm: false)
        return ENV["BROWSERCTL_STATE_PASSPHRASE"] if ENV["BROWSERCTL_STATE_PASSPHRASE"]

        $stderr.print "Passphrase: "
        pass = $stdin.noecho(&:gets).to_s.chomp
        $stderr.puts

        if confirm
          $stderr.print "Confirm passphrase: "
          confirm_pass = $stdin.noecho(&:gets).to_s.chomp
          $stderr.puts
          abort "Passphrases do not match." unless pass == confirm_pass
        end

        pass
      end
      private_class_method :prompt_passphrase

      # Peek at the manifest first so we only prompt for a passphrase when needed.
      def self.state_needs_passphrase?(client, name)
        info = client.state_info(name)
        return false if info[:error] || info["error"]

        manifest = info[:info] || info["info"] || {}
        manifest[:encrypted] || manifest["encrypted"] || false
      end
      private_class_method :state_needs_passphrase?
    end
  end
end

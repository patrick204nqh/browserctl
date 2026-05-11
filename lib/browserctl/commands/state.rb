# frozen_string_literal: true

require "json"
require_relative "cli_output"
require_relative "output_format"
require_relative "passphrase_prompt"

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
        passphrase  = encrypt ? PassphrasePrompt.read(confirm: true) : nil
        origin_list = origins ? origins.split(",").map(&:strip).reject(&:empty?) : nil
        print_result(client.state_save(name, origins: origin_list, flow: flow, passphrase: passphrase))
      end

      def self.run_load(client, args)
        name = args.shift or abort "usage: browserctl state load <name>"
        passphrase = PassphrasePrompt.needed_for?(client, name) ? PassphrasePrompt.read : nil
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

      # Re-runs the flow bound to <name> and re-saves it. Mutation logic
      # lives in {Browserctl::State::Mutator}; this method is CLI plumbing.
      def self.run_rotate(client, args)
        require "browserctl/state/mutator"
        require "browserctl/runner"
        page_name   = extract_value!(args, "--page")
        params_path = extract_value!(args, "--params")
        name        = args.shift or abort "usage: browserctl state rotate <name> " \
                                          "[--page NAME] [--params FILE] [--key value ...]"

        file_params = params_path ? Browserctl::Runner.load_params_file(params_path) : {}
        cli_params  = args.each_slice(2).to_h { |flag, val| [flag.to_s.sub(/\A--/, "").to_sym, val] }
        page        = page_name ? Browserctl::PageProxy.new(page_name, client) : nil

        result = Browserctl::State::Mutator.new(client: client)
                                           .rotate(name: name, params: file_params.merge(cli_params), page: page)
        print_result(result.to_h)
      rescue Browserctl::FlowError => e
        warn "Error: #{e.message}"
        exit 1
      end

      def self.run_export(args)
        name        = args.shift or abort "usage: browserctl state export <name> <destination>"
        destination = args.shift or abort "usage: browserctl state export <name> <destination>"
        require "browserctl/state"
        OutputFormat.current.emit(Browserctl::State.export(name, destination))
      rescue Browserctl::State::Transport::TransportError, Browserctl::Error, ArgumentError => e
        warn "Error: #{e.message}"
        exit 1
      end

      def self.run_import(args)
        name_override = extract_value!(args, "--name")
        source        = args.shift or abort "usage: browserctl state import <source> [--name NAME]"
        require "browserctl/state"
        OutputFormat.current.emit(Browserctl::State.import(source, name: name_override))
      rescue Browserctl::State::Transport::TransportError, Browserctl::State::Bundle::BundleError,
             Browserctl::Error, ArgumentError => e
        warn "Error: #{e.message}"
        exit 1
      end

      def self.extract_value!(args, flag)
        idx = args.index(flag) or return nil
        args.delete_at(idx)
        args.delete_at(idx) or abort "missing value for #{flag}"
      end
      private_class_method :extract_value!
    end
  end
end

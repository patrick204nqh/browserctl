# frozen_string_literal: true

require "io/console"
require "json"
require_relative "cli_output"

module Browserctl
  module Commands
    # `browserctl state` — top-level command for portable, encrypted, origin-
    # scoped browser state. Wraps the daemon's state_* RPCs.
    module State
      extend CliOutput

      USAGE = "Usage: browserctl state <save|load|list|info|delete> [args]"

      def self.run(client, args)
        sub = args.shift or abort USAGE
        case sub
        when "save"   then run_save(client, args)
        when "load"   then run_load(client, args)
        when "list"   then run_list(client)
        when "info"   then run_info(client, args)
        when "delete" then run_delete(client, args)
        else abort "unknown state subcommand '#{sub}'\n#{USAGE}"
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

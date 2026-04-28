# frozen_string_literal: true

require_relative "cli_output"

module Browserctl
  module Commands
    module Session
      extend CliOutput

      USAGE = "Usage: browserctl session <save|load|list|delete|export|import> [args]"

      # rubocop:disable Metrics/CyclomaticComplexity
      def self.run(client, args)
        sub = args.shift or abort USAGE
        case sub
        when "save"   then run_save(client, args)
        when "load"   then run_load(client, args)
        when "list"   then run_list(client)
        when "delete" then run_delete(client, args)
        when "export" then run_export(args)
        when "import" then run_import(args)
        else abort "unknown session subcommand '#{sub}'\n#{USAGE}"
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      def self.run_save(client, args)
        name = args.shift or abort "usage: browserctl session save <name>"
        print_result(client.session_save(name))
      end

      def self.run_load(client, args)
        name = args.shift or abort "usage: browserctl session load <name>"
        print_result(client.session_load(name))
      end

      def self.run_list(client)
        print_result(client.session_list)
      end

      def self.run_delete(client, args)
        name = args.shift or abort "usage: browserctl session delete <name>"
        print_result(client.session_delete(name))
      end

      def self.run_export(args)
        name = args.shift or abort "usage: browserctl session export <name> <path>"
        dest = args.shift or abort "usage: browserctl session export <name> <path>"
        session_dir = File.join(Browserctl::BROWSERCTL_DIR, "sessions", name)
        abort "session '#{name}' not found" unless Dir.exist?(session_dir)

        dest = File.expand_path(dest)
        pid = Process.spawn("zip", "-r", dest, name, chdir: File.join(Browserctl::BROWSERCTL_DIR, "sessions"))
        Process.wait(pid)
        puts({ ok: true, path: dest }.to_json)
      end

      def self.run_import(args)
        zip_path = args.shift or abort "usage: browserctl session import <path>"
        zip_path = File.expand_path(zip_path)
        abort "zip file not found: #{zip_path}" unless File.exist?(zip_path)

        sessions_dir = File.join(Browserctl::BROWSERCTL_DIR, "sessions")
        FileUtils.mkdir_p(sessions_dir)
        pid = Process.spawn("unzip", "-o", zip_path, "-d", sessions_dir)
        Process.wait(pid)
        puts({ ok: true }.to_json)
      end
    end
  end
end

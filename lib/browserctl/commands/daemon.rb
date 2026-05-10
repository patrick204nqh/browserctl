# frozen_string_literal: true

require "json"
require "optimist"
require_relative "cli_output"
require_relative "output_format"

module Browserctl
  module Commands
    module Daemon
      extend CliOutput

      USAGE = "Usage: browserctl daemon <ping|status|start|stop|list> [args]"

      def self.run(client, args)
        sub = args.shift or abort USAGE
        case sub
        when "ping"
          begin
            print_result(client.ping)
          rescue Browserctl::DaemonUnavailableError => e
            payload = { ok: false, daemon: "offline", error: e.message }
            OutputFormat.current.emit(payload)
            exit 1
          end
        when "status" then run_status(client)
        when "start"  then run_start(args)
        when "stop"   then print_result(client.shutdown)
        when "list"   then run_list
        else abort "unknown daemon subcommand '#{sub}'\n#{USAGE}"
        end
      end

      def self.run_status(client)
        ping = client.ping
        pages = client.page_list[:pages] || []
        page_info = pages.map do |name|
          url_res = client.url(name)
          { name: name, url: url_res[:url] || url_res[:error] }
        end
        payload = {
          daemon: "online",
          pid: ping[:pid],
          protocol_version: ping[:protocol_version],
          pages: page_info
        }
        OutputFormat.current.emit(payload, JSON.pretty_generate(payload))
      rescue Browserctl::DaemonUnavailableError => e
        payload = { daemon: "offline", error: e.message }
        OutputFormat.current.emit(payload, JSON.pretty_generate(payload))
        exit 1
      end

      def self.run_start(args)
        opts = Optimist.options(args) do
          opt :headed, "Run with visible browser", default: false
          opt :name,   "Daemon name", type: :string
        end
        flags = []
        flags << "--headed" if opts[:headed]
        flags += ["--name", opts[:name]] if opts[:name]
        pid = Process.spawn("browserd", *flags, out: File::NULL, err: File::NULL)
        Process.detach(pid)
        OutputFormat.current.emit({ ok: true, pid: pid }) { "browserd started (pid #{pid})" }
      end

      def self.run_list
        sockets = Dir[File.join(Browserctl::BROWSERCTL_DIR, "*.sock")]
        rows = sockets.map do |sock_path|
          daemon_name = File.basename(sock_path, ".sock")
          display_name = daemon_name == "browserd" ? "default" : daemon_name
          socket_name = daemon_name == "browserd" ? nil : daemon_name
          client = Browserctl::Client.new(Browserctl.socket_path(socket_name))
          status = client.ping
          next unless status&.dig(:ok)

          { name: display_name, pid: status[:pid], pages: (client.page_list[:pages] || []).length }
        rescue Browserctl::DaemonUnavailableError, RuntimeError
          nil
        end.compact
        OutputFormat.current.emit({ daemons: rows })
      end
    end
  end
end

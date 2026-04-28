# frozen_string_literal: true

require "json"
require "optimist"
require_relative "cli_output"

module Browserctl
  module Commands
    module Daemon
      extend CliOutput

      USAGE = "Usage: browserctl daemon <ping|status|start|stop|list> [args]"

      def self.run(client, args)
        sub = args.shift or abort USAGE
        case sub
        when "ping"   then print_result(client.ping)
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
        puts JSON.pretty_generate(
          daemon: "online",
          pid: ping[:pid],
          protocol_version: ping[:protocol_version],
          pages: page_info
        )
      rescue RuntimeError => e
        raise unless e.message.include?("browserd is not running")

        puts JSON.pretty_generate(daemon: "offline", error: e.message)
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
        puts "browserd started (pid #{pid})"
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
        rescue RuntimeError
          nil
        end.compact
        puts({ daemons: rows }.to_json)
      end
    end
  end
end

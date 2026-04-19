# frozen_string_literal: true

require "ferrum"
require "socket"
require "json"
require "fileutils"
require_relative "constants"
require_relative "server/command_dispatcher"
require_relative "server/idle_watcher"

module Browserctl
  class Server
    def initialize(headless: true)
      prepare_runtime(headless)
      @dispatcher = CommandDispatcher.new(@pages, @browser)
    end

    def run
      write_pid
      server, idle = setup_server
      serve(server)
    rescue SignalException
      # clean shutdown
    ensure
      teardown(idle, server)
    end

    private

    def prepare_runtime(headless)
      FileUtils.mkdir_p(File.dirname(SOCKET_PATH))
      @browser = init_browser(headless)
      init_state
    end

    def init_browser(headless)
      Ferrum::Browser.new(
        headless: headless,
        timeout: 30,
        process_timeout: 30,
        browser_options: { "disable-dev-shm-usage" => nil, "disable-gpu" => nil }
      )
    end

    def init_state
      @pages     = {}
      @last_used = Time.now
      @mutex     = Mutex.new
    end

    def setup_server
      server = setup_socket
      idle   = Thread.new { IdleWatcher.new(-> { @mutex.synchronize { @last_used } }).watch(server) }
      [server, idle]
    end

    def setup_socket
      FileUtils.rm_f(SOCKET_PATH)
      server = UNIXServer.new(SOCKET_PATH)
      File.chmod(0o600, SOCKET_PATH)
      announce_socket
      server
    end

    def announce_socket
      $stdout.puts "browserd listening on #{SOCKET_PATH}"
      $stdout.flush
    end

    def serve(server)
      loop do
        client = server.accept
        Thread.new(client) { |c| handle(c) }
      end
    end

    def handle(socket)
      if (line = socket.gets)
        @mutex.synchronize { @last_used = Time.now }
        socket.puts JSON.generate(process(line))
      end
    rescue StandardError => e
      quietly { socket.puts JSON.generate({ error: e.message }) }
    ensure
      quietly { socket.close }
    end

    def process(line)
      req = JSON.parse(line.chomp, symbolize_names: true)
      @mutex.synchronize { @dispatcher.dispatch(req) }
    end

    def teardown(idle, server)
      idle&.kill
      quietly { server&.close }
      quietly { @browser.quit }
      quietly { File.unlink(SOCKET_PATH) }
      quietly { File.unlink(PID_PATH) }
    end

    def write_pid
      File.write(PID_PATH, Process.pid.to_s)
    end

    def quietly
      yield
    rescue StandardError
      nil
    end
  end
end

# frozen_string_literal: true

require "ferrum"
require "socket"
require "json"
require "fileutils"
require "timeout"
require_relative "constants"
require_relative "logger"
require_relative "server/command_dispatcher"
require_relative "server/idle_watcher"
require_relative "server/page_session"

module Browserctl
  class Server
    def initialize(headless: true, socket_path: SOCKET_PATH, pid_path: PID_PATH)
      @socket_path = socket_path
      @pid_path    = pid_path
      prepare_runtime(headless)
      @dispatcher = CommandDispatcher.new(@pages, @browser, global_mutex: @mutex)
    end

    def run
      guard_already_running!
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
      FileUtils.mkdir_p(File.dirname(@socket_path))
      @browser = init_browser(headless)
      init_state
    end

    def init_browser(headless)
      Ferrum::Browser.new(headless: headless, **ferrum_options)
    end

    def ferrum_options
      { timeout: 30, process_timeout: 30,
        browser_options: { "no-sandbox" => nil, "disable-dev-shm-usage" => nil, "disable-gpu" => nil } }
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
      FileUtils.rm_f(@socket_path)
      old_umask = File.umask(0o177)
      server = UNIXServer.new(@socket_path)
      File.umask(old_umask)
      Browserctl.logger.info "daemon ready — listening on #{@socket_path}"
      server
    end

    def guard_already_running!
      return unless File.exist?(@pid_path)

      pid = File.read(@pid_path).strip.to_i
      return unless pid.positive?

      Process.kill(0, pid)
      abort "browserd already running (PID #{pid}). Use 'browserctl daemon stop' first."
    rescue Errno::ESRCH
      # Dead process — stale PID file, safe to continue
    rescue Errno::EPERM
      abort "browserd (PID #{pid}) is running as a different user. Remove #{@pid_path} manually if stale."
    end

    def serve(server)
      loop do
        client = server.accept
        Thread.new(client) { |c| handle(c) }
      end
    end

    def handle(socket)
      dispatch(socket, socket.gets)
    rescue StandardError => e
      Browserctl.logger.error "#{e.class}: #{e.message}"
      quietly { socket.puts JSON.generate({ error: e.message }) }
    ensure
      quietly { socket.close }
    end

    def dispatch(socket, line)
      return unless line

      socket.puts JSON.generate(process(line))
    end

    def process(line)
      req = JSON.parse(line.chomp, symbolize_names: true)
      @mutex.synchronize { @last_used = Time.now }
      @dispatcher.dispatch(req)
    end

    def teardown(idle, server)
      idle&.kill
      quietly { server&.close }
      quietly { Timeout.timeout(5) { @browser.quit } }
      quietly { File.unlink(@socket_path) }
      quietly { File.unlink(@pid_path) }
    end

    def write_pid
      File.write(@pid_path, Process.pid.to_s)
    end

    def quietly
      yield
    rescue Exception
      nil
    end
  end
end

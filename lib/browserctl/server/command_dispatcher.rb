# frozen_string_literal: true

require_relative "snapshot_builder"
require_relative "page_session"
require_relative "handlers/page_lifecycle"
require_relative "handlers/navigation"
require_relative "handlers/observation"
require_relative "handlers/cookies"
require_relative "handlers/hitl"
require_relative "handlers/devtools"
require_relative "handlers/daemon_control"
require_relative "../detectors"
require_relative "../policy"

module Browserctl
  class CommandDispatcher
    include Handlers::PageLifecycle
    include Handlers::Navigation
    include Handlers::Observation
    include Handlers::Cookies
    include Handlers::Hitl
    include Handlers::DevTools
    include Handlers::DaemonControl

    COMMAND_MAP = {
      "open_page" => :cmd_open_page,
      "close_page" => :cmd_close_page,
      "list_pages" => :cmd_list_pages,
      "goto" => :cmd_goto,
      "snapshot" => :cmd_snapshot,
      "evaluate" => :cmd_evaluate,
      "fill" => :cmd_fill,
      "click" => :cmd_click,
      "screenshot" => :cmd_screenshot,
      "wait_for" => :cmd_wait_for,
      "watch" => :cmd_watch,
      "url" => :cmd_url,
      "ping" => :cmd_ping,
      "shutdown" => :cmd_shutdown,
      "pause" => :cmd_pause,
      "resume" => :cmd_resume,
      "inspect" => :cmd_inspect,
      "cookies" => :cmd_cookies,
      "set_cookie" => :cmd_set_cookie,
      "clear_cookies" => :cmd_clear_cookies,
      "import_cookies" => :cmd_import_cookies,
      "store" => :cmd_store,
      "fetch" => :cmd_fetch
    }.freeze

    SCREENSHOT_DIR   = File.expand_path("~/.browserctl/screenshots").freeze
    SCREENSHOT_ROOTS = [SCREENSHOT_DIR, File.expand_path(".")].freeze
    SCREENSHOT_EXTS  = %w[.png .jpg .jpeg].freeze

    def initialize(pages, browser, snapshot_builder = SnapshotBuilder.new, global_mutex: Mutex.new)
      @pages            = pages
      @browser          = browser
      @snapshot_builder = snapshot_builder
      @global_mutex     = global_mutex
      @kv_store         = {}
      @kv_mutex         = Mutex.new
    end

    # Dispatches a parsed request to the appropriate handler.
    # Returns `{ error: String, code: String }` for unknown commands.
    # @param req [Hash{Symbol => Object}] parsed request; must include `:cmd`
    # @return [Hash{Symbol => Object}] response; always includes `:ok` or `:error`
    def dispatch(req)
      handler = COMMAND_MAP[req[:cmd]]
      if handler
        Browserctl.logger.debug("#{req[:cmd]} #{req[:name]}")
        return send(handler, req)
      end

      if (plugin = Browserctl.lookup_plugin_command(req[:cmd]))
        Browserctl.logger.debug("plugin:#{req[:cmd]} #{req[:name]}")
        session = req[:name] ? @global_mutex.synchronize { @pages[req[:name]] } : nil
        return plugin.call(session, req)
      end

      { error: "unknown command: #{req[:cmd]}" }
    end

    private

    def with_page(name)
      session = @global_mutex.synchronize { @pages[name] }
      return { error: "no page named '#{name}'" } unless session

      session.mutex.synchronize do
        session.pause_cv.wait(session.mutex) while session.paused?
        yield session
      end
    end
  end
end

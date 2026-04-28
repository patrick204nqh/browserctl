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
require_relative "handlers/storage"
require_relative "handlers/session"
require_relative "handlers/interaction"
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
    include Handlers::Storage
    include Handlers::Session
    include Handlers::Interaction

    COMMAND_MAP = {
      "page_open" => :cmd_page_open,
      "page_close" => :cmd_page_close,
      "page_list" => :cmd_page_list,
      "page_focus" => :cmd_page_focus,
      "navigate" => :cmd_navigate,
      "wait" => :cmd_wait,
      "snapshot" => :cmd_snapshot,
      "evaluate" => :cmd_evaluate,
      "fill" => :cmd_fill,
      "click" => :cmd_click,
      "screenshot" => :cmd_screenshot,
      "url" => :cmd_url,
      "ping" => :cmd_ping,
      "shutdown" => :cmd_shutdown,
      "pause" => :cmd_pause,
      "resume" => :cmd_resume,
      "devtools" => :cmd_devtools,
      "cookies" => :cmd_cookies,
      "set_cookie" => :cmd_set_cookie,
      "delete_cookies" => :cmd_delete_cookies,
      "import_cookies" => :cmd_import_cookies,
      "store" => :cmd_store,
      "fetch" => :cmd_fetch,
      "storage_get" => :cmd_storage_get,
      "storage_set" => :cmd_storage_set,
      "storage_export" => :cmd_storage_export,
      "storage_import" => :cmd_storage_import,
      "storage_delete" => :cmd_storage_delete,
      "press" => :cmd_press,
      "hover" => :cmd_hover,
      "upload" => :cmd_upload,
      "select" => :cmd_select,
      "dialog_accept" => :cmd_dialog_accept,
      "dialog_dismiss" => :cmd_dialog_dismiss,
      "session_save" => :cmd_session_save,
      "session_load" => :cmd_session_load,
      "session_list" => :cmd_session_list,
      "session_delete" => :cmd_session_delete
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

# frozen_string_literal: true

require "fileutils"
require "socket"
require "json"
require_relative "constants"
require_relative "recording"

module Browserctl
  # Thin IPC client that wraps each browserd command as a Ruby method call.
  class Client
    def initialize(socket_path = nil)
      @socket_path = socket_path || auto_discover_socket
    end

    def call(cmd, **params)
      result = communicate(JSON.generate({ cmd: cmd }.merge(params)))
      Recording.append(cmd, **params) if result[:ok]
      result
    rescue Errno::ENOENT, Errno::ECONNREFUSED
      raise "browserd is not running — start it with: browserd"
    end

    # Opens or focuses a named browser page.
    # @param name [String] logical page name
    # @param url [String, nil] optional URL to navigate to after opening
    # @return [Hash] `{ ok: true, name: }` or `{ error: }`
    def page_open(name, url: nil)  = call("page_open",  name: name, url: url)

    # Closes a named page and removes it from the session.
    # @param name [String] logical page name
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def page_close(name)           = call("page_close", name: name)

    # Lists all open page names.
    # @return [Hash] `{ pages: [String] }`
    def page_list                  = call("page_list")

    # Navigates a page to a URL. Returns `challenge: true` when Cloudflare is detected.
    # @param name [String] logical page name
    # @param url [String] destination URL
    # @return [Hash] `{ ok: true, url:, challenge: }` or `{ error: }`
    def navigate(name, url)        = call("navigate", name: name, url: url)

    # Clicks an element identified by CSS selector or snapshot ref.
    # @param name [String] logical page name
    # @param selector [String, nil] CSS selector
    # @param ref [String, nil] snapshot ref (e.g. "e3")
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def click(name, selector = nil, ref: nil)
      raise ArgumentError, "click: provide selector or ref:" unless selector || ref

      call("click", name: name, selector: selector, ref: ref)
    end

    # Fills an input element with a value.
    # @param name [String] logical page name
    # @param selector [String, nil] CSS selector
    # @param value [String, nil] text to type
    # @param ref [String, nil] snapshot ref
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def fill(name, selector = nil, value = nil, ref: nil)
      raise ArgumentError, "fill: provide selector or ref:" unless selector || ref

      call("fill", name: name, selector: selector, ref: ref, value: value)
    end

    # Takes a screenshot of a named page.
    # @param name [String] logical page name
    # @param path [String, nil] output path (default: ~/.browserctl/screenshots/)
    # @param full [Boolean] capture full page (default: false)
    # @return [Hash] `{ ok: true, path: }` or `{ error: }`
    def screenshot(name, path: nil, full: false) = call("screenshot", name: name, path: path, full: full)

    # Takes a DOM snapshot. Returns `challenge: true` when Cloudflare is detected.
    # @param name [String] logical page name
    # @param format [String] "elements" (interactable elements JSON) or "html" (raw HTML)
    # @param diff [Boolean] return only elements changed since last snapshot
    # @return [Hash] `{ ok: true, snapshot:, challenge: }` or `{ ok: true, html:, challenge: }` or `{ error: }`
    def snapshot(name, format: "elements", diff: false)
      call("snapshot", name: name, format: format, diff: diff)
    end

    # Waits for a CSS selector to appear within the given timeout.
    # @param name [String] logical page name
    # @param selector [String] CSS selector to wait for
    # @param timeout [Numeric] seconds before giving up (default: 30)
    # @return [Hash] `{ ok: true, selector: }` or `{ error: }`
    def wait(name, selector, timeout: 30) = call("wait", name: name, selector: selector, timeout: timeout)

    # Returns the current URL of a named page.
    # @param name [String] logical page name
    # @return [Hash] `{ ok: true, url: }` or `{ error: }`
    def url(name)                  = call("url",      name: name)

    # Evaluates a JavaScript expression and returns the result.
    # @param name [String] logical page name
    # @param expression [String] JavaScript expression
    # @return [Hash] `{ ok: true, result: }` or `{ error: }`
    def evaluate(name, expression) = call("evaluate", name: name, expression: expression)

    # Checks if browserd is alive.
    # @return [Hash] `{ ok: true, pid: }` or raises if daemon is not running
    def ping                       = call("ping")

    # Shuts down browserd gracefully.
    # @return [Hash] `{ ok: true }`
    def shutdown                   = call("shutdown")

    # Pauses automation on a page so a human can interact directly.
    # @param name [String] logical page name
    # @param message [String, nil] optional message displayed to the human
    # @return [Hash] `{ ok: true, paused: true, message: }` or `{ error: }`
    def pause(name, message: nil)  = call("pause",  name: name, message: message)

    # Resumes automation on a paused page.
    # @param name [String] logical page name
    # @return [Hash] `{ ok: true, paused: false }` or `{ error: }`
    def resume(name)               = call("resume", name: name)

    # Returns the Chrome DevTools URL for a named page.
    # @param name [String] logical page name
    # @return [Hash] `{ ok: true, devtools_url: }` or `{ error: }`
    def devtools(name)             = call("devtools", name: name)

    # Brings the named page's tab to front. Only works when browserd was started with --headed.
    # @param name [String] logical page name
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def page_focus(name) = call("page_focus", name: name)

    # Stores a value in the daemon-scoped key-value store.
    # @param key [String] storage key
    # @param value [Object] value to store (must be JSON-serialisable)
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def store(key, value)          = call("store", key: key, value: value)

    # Retrieves a value from the daemon-scoped key-value store.
    # @param key [String] storage key
    # @return [Hash] `{ ok: true, value: }` or `{ error:, code: "key_not_found" }`
    def fetch(key)                 = call("fetch", key: key)

    # Returns all cookies for a named page.
    # @param name [String] logical page name
    # @return [Hash] `{ ok: true, cookies: [Hash] }` or `{ error: }`
    def cookies(name)              = call("cookies", name: name)

    # Sets a cookie on a named page.
    # @param name [String] logical page name
    # @param cookie_name [String] cookie name (e.g. "cf_clearance")
    # @param value [String] cookie value
    # @param domain [String] cookie domain (e.g. ".example.com")
    # @param path [String] cookie path (default: "/")
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def set_cookie(name, cookie_name, value, domain, path: "/")
      call("set_cookie", name: name, cookie_name: cookie_name,
                         value: value, domain: domain, path: path)
    end

    # Deletes all cookies for a named page.
    # @param name [String] logical page name
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def delete_cookies(name) = call("delete_cookies", name: name)

    # Exports all cookies for a named page to a JSON file.
    # File I/O is client-side; daemon provides the cookie data.
    # @param name [String] logical page name
    # @param path [String] file path to write cookies to
    # @return [Hash] `{ ok: true, path:, count: }` or `{ error: }`
    def export_cookies(name, path)
      result = call("cookies", name: name)
      return result unless result[:ok]

      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "w", 0o600) { |f| f.write(JSON.generate(result[:cookies])) }
      { ok: true, path: path, count: result[:cookies].length }
    end

    # Imports cookies from a JSON file into a named page.
    # @param name [String] logical page name
    # @param path [String] file path to read cookies from
    # @return [Hash] `{ ok: true, count: }` or `{ error: }`
    def import_cookies(name, path)
      raise "cookie file not found: #{path}" unless File.exist?(path)

      cookies = JSON.parse(File.read(path), symbolize_names: true)
      call("import_cookies", name: name, cookies: cookies)
    end

    # Returns the value of a localStorage or sessionStorage key.
    # @param name [String] logical page name
    # @param key [String] storage key
    # @param store [String] "local" or "session" (default: "local")
    # @return [Hash] `{ ok: true, value: }` or `{ error: }`
    def storage_get(name, key, store: "local")
      call("storage_get", name: name, key: key, store: store)
    end

    # Sets a localStorage or sessionStorage key.
    # @param name [String] logical page name
    # @param key [String] storage key
    # @param value [String] storage value
    # @param store [String] "local" or "session" (default: "local")
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def storage_set(name, key, value, store: "local")
      call("storage_set", name: name, key: key, value: value, store: store)
    end

    # Exports localStorage and/or sessionStorage to a JSON file.
    # @param name [String] logical page name
    # @param path [String] destination file path
    # @param stores [String] "local", "session", or "all" (default: "all")
    # @return [Hash] `{ ok: true, path:, key_count: }` or `{ error: }`
    def storage_export(name, path, stores: "all")
      call("storage_export", name: name, path: path, stores: stores)
    end

    # Imports storage keys from a JSON file into the page's localStorage.
    # @param name [String] logical page name
    # @param path [String] source file path
    # @return [Hash] `{ ok: true, origins: N, key_count: M }` or `{ error: }`
    def storage_import(name, path)
      call("storage_import", name: name, path: path)
    end

    # Clears localStorage and/or sessionStorage for the page.
    # @param name [String] logical page name
    # @param stores [String] "local", "session", or "all" (default: "all")
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def storage_delete(name, stores: "all")
      call("storage_delete", name: name, stores: stores)
    end

    # Fires a keydown + keyup event for the given key name on a page.
    # @param name [String] logical page name
    # @param key [String] key name e.g. "Enter", "Tab", "Escape", "ArrowDown"
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def press(name, key)          = call("press",  name: name, key: key)

    # Moves the mouse to the centre of the element matched by selector.
    # @param name [String] logical page name
    # @param selector [String] CSS selector
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def hover(name, selector)     = call("hover",  name: name, selector: selector)

    # Sets a file-input element to the given file path.
    # @param name [String] logical page name
    # @param selector [String] CSS selector for the file input
    # @param path [String] absolute or relative file path
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def upload(name, selector, path) = call("upload", name: name, selector: selector, path: path)

    # Sets a <select> element's value and fires a change event.
    # @param name [String] logical page name
    # @param selector [String] CSS selector for the select element
    # @param value [String] option value to select
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def select(name, selector, value) = call("select", name: name, selector: selector, value: value)

    # Pre-registers a one-shot handler to accept the next JS dialog on a page.
    # @param name [String] logical page name
    # @param text [String, nil] prompt text for window.prompt dialogs (ignored for alert/confirm)
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def dialog_accept(name, text: nil) = call("dialog_accept", name: name, text: text)

    # Pre-registers a one-shot handler to dismiss the next JS dialog on a page.
    # @param name [String] logical page name
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def dialog_dismiss(name)           = call("dialog_dismiss", name: name)

    # Saves the current browser state (cookies, localStorage, open pages) to a named session.
    # @param session_name [String] name for the saved session
    # @return [Hash] `{ ok: true, path:, pages: N, cookies: N }` or `{ error: }`
    def session_save(session_name)
      call("session_save", session_name: session_name)
    end

    # Restores a previously saved session into the running daemon.
    # @param session_name [String] name of the session to load
    # @return [Hash] `{ ok: true, cookies: N, pages: N, local_storage_keys: N }` or `{ error: }`
    def session_load(session_name)
      call("session_load", session_name: session_name)
    end

    # Lists all saved sessions.
    # @return [Hash] `{ ok: true, sessions: [Hash] }` or `{ error: }`
    def session_list
      call("session_list")
    end

    # Permanently deletes a named session.
    # @param session_name [String] name of the session to delete
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def session_delete(session_name)
      call("session_delete", session_name: session_name)
    end

    private

    def auto_discover_socket
      default = Browserctl.socket_path
      return default if File.exist?(default)

      # Fall back to the first available auto-indexed daemon, or the default path
      # (which will raise "browserd is not running" at connection time if absent).
      Browserctl.all_daemon_sockets.first || default
    end

    def communicate(payload)
      UNIXSocket.open(@socket_path) do |sock|
        sock.puts(payload)
        read_response(sock)
      end
    end

    def read_response(sock)
      raise "browserd response timeout after 60s" unless sock.wait_readable(60)

      raw = sock.gets
      raise "browserd closed connection" unless raw

      JSON.parse(raw.chomp, symbolize_names: true)
    end
  end
end

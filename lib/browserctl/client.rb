# frozen_string_literal: true

require "socket"
require "json"
require_relative "constants"
require_relative "recording"

module Browserctl
  # Thin IPC client that wraps each browserd command as a Ruby method call.
  class Client
    def initialize(socket_path = Browserctl.socket_path)
      @socket_path = socket_path
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
    def open_page(name, url: nil)  = call("open_page",  name: name, url: url)

    # Closes a named page and removes it from the session.
    # @param name [String] logical page name
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def close_page(name)           = call("close_page", name: name)

    # Lists all open page names.
    # @return [Hash] `{ pages: [String] }`
    def list_pages                 = call("list_pages")

    # Navigates a page to a URL. Returns `challenge: true` when Cloudflare is detected.
    # @param name [String] logical page name
    # @param url [String] destination URL
    # @return [Hash] `{ ok: true, url:, challenge: }` or `{ error: }`
    def goto(name, url)            = call("goto", name: name, url: url)

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
    # @param format [String] "ai" (token-efficient JSON) or "html" (raw HTML)
    # @param diff [Boolean] return only elements changed since last snapshot
    # @return [Hash] `{ ok: true, snapshot:, challenge: }` or `{ ok: true, html:, challenge: }` or `{ error: }`
    def snapshot(name, format: "ai", diff: false)
      call("snapshot", name: name, format: format, diff: diff)
    end

    # Waits for a CSS selector to appear (short timeout).
    # @param name [String] logical page name
    # @param selector [String] CSS selector to wait for
    # @param timeout [Numeric] seconds before giving up (default: 10)
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def wait_for(name, selector, timeout: 10) = call("wait_for", name: name, selector: selector, timeout: timeout)

    # Polls for a CSS selector with a longer timeout (suitable for async operations).
    # @param name [String] logical page name
    # @param selector [String] CSS selector to poll for
    # @param timeout [Numeric] seconds before giving up (default: 30)
    # @return [Hash] `{ ok: true, selector: }` or `{ error: }`
    def watch(name, selector, timeout: 30)
      call("watch", name: name, selector: selector, timeout: timeout)
    end

    # Returns the current URL of a named page.
    # @param name [String] logical page name
    # @return [Hash] `{ ok: true, url: }` or `{ error: }`
    def url(name)                  = call("url",         name: name)

    # Evaluates a JavaScript expression and returns the result.
    # @param name [String] logical page name
    # @param expression [String] JavaScript expression
    # @return [Hash] `{ ok: true, result: }` or `{ error: }`
    def evaluate(name, expression) = call("evaluate",    name: name, expression: expression)

    # Checks if browserd is alive.
    # @return [Hash] `{ ok: true, pid: }` or raises if daemon is not running
    def ping                       = call("ping")

    # Shuts down browserd gracefully.
    # @return [Hash] `{ ok: true }`
    def shutdown                   = call("shutdown")

    # Pauses automation on a page so a human can interact directly.
    # @param name [String] logical page name
    # @return [Hash] `{ ok: true, paused: true }` or `{ error: }`
    def pause(name)                = call("pause",   name: name)

    # Resumes automation on a paused page.
    # @param name [String] logical page name
    # @return [Hash] `{ ok: true, paused: false }` or `{ error: }`
    def resume(name)               = call("resume",  name: name)

    # Returns the Chrome DevTools URL for a named page.
    # @param name [String] logical page name
    # @return [Hash] `{ ok: true, devtools_url: }` or `{ error: }`
    def inspect_page(name)         = call("inspect", name: name)

    # Returns all cookies for a named page.
    # @param name [String] logical page name
    # @return [Hash] `{ ok: true, cookies: [Hash] }` or `{ error: }`
    def cookies(name) = call("cookies", name: name)

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

    # Clears all cookies for a named page.
    # @param name [String] logical page name
    # @return [Hash] `{ ok: true }` or `{ error: }`
    def clear_cookies(name) = call("clear_cookies", name: name)

    # Exports all cookies for a named page to a JSON file.
    # @param name [String] logical page name
    # @param path [String] file path to write cookies to
    # @return [Hash] `{ ok: true, path:, count: }` or `{ error: }`
    def export_cookies(name, path)
      result = call("cookies", name: name)
      return result unless result[:ok]

      File.write(path, JSON.generate(result[:cookies]))
      { ok: true, path: path, count: result[:cookies].length }
    end

    # Imports cookies from a JSON file into a named page.
    # @param name [String] logical page name
    # @param path [String] file path to read cookies from
    # @return [Hash] `{ ok: true, count: }` or `{ error: }`
    def import_cookies(name, path)
      raise "params file not found: #{path}" unless File.exist?(path)

      cookies = JSON.parse(File.read(path), symbolize_names: true)
      call("import_cookies", name: name, cookies: cookies)
    end

    private

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

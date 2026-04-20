# frozen_string_literal: true

require "socket"
require "json"
require_relative "constants"
require_relative "recording"

module Browserctl
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

    # Convenience wrappers matching CLI command vocabulary

    def open_page(name, url: nil)  = call("open_page",  name: name, url: url)
    def close_page(name)           = call("close_page", name: name)
    def list_pages                 = call("list_pages")
    def goto(name, url)            = call("goto", name: name, url: url)

    def click(name, selector = nil, ref: nil)
      raise ArgumentError, "click: provide selector or ref:" unless selector || ref

      call("click", name: name, selector: selector, ref: ref)
    end

    def fill(name, selector = nil, value = nil, ref: nil)
      raise ArgumentError, "fill: provide selector or ref:" unless selector || ref

      call("fill", name: name, selector: selector, ref: ref, value: value)
    end

    def screenshot(name, path: nil, full: false) = call("screenshot", name: name, path: path, full: full)

    def snapshot(name, format: "ai", diff: false)
      call("snapshot", name: name, format: format, diff: diff)
    end

    def wait_for(name, selector, timeout: 10) = call("wait_for", name: name, selector: selector, timeout: timeout)

    def watch(name, selector, timeout: 30)
      call("watch", name: name, selector: selector, timeout: timeout)
    end

    def url(name)                  = call("url",         name: name)
    def evaluate(name, expression) = call("evaluate",    name: name, expression: expression)
    def ping                       = call("ping")
    def shutdown                   = call("shutdown")

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

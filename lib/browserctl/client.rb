# frozen_string_literal: true

require "socket"
require "json"
require_relative "constants"

module Browserctl
  class Client
    def initialize(socket_path = SOCKET_PATH)
      @socket_path = socket_path
    end

    def call(cmd, **params)
      communicate(JSON.generate({ cmd: cmd }.merge(params)))
    rescue Errno::ENOENT, Errno::ECONNREFUSED
      raise "browserd is not running — start it with: browserd"
    end

    # Convenience wrappers matching CLI command vocabulary

    def open_page(name, url: nil)  = call("open_page",  name: name, url: url)
    def close_page(name)           = call("close_page", name: name)
    def list_pages                 = call("list_pages")
    def goto(name, url)            = call("goto",        name: name, url: url)
    def click(name, selector = nil, ref: nil)
      raise ArgumentError, "click: provide selector or ref:" unless selector || ref
      call("click", name: name, selector: selector, ref: ref)
    end

    def fill(name, selector = nil, value = nil, ref: nil)
      raise ArgumentError, "fill: provide selector or ref:" unless selector || ref
      call("fill", name: name, selector: selector, ref: ref, value: value)
    end
    def screenshot(name, path: nil, full: false) = call("screenshot", name: name, path: path, full: full)
    def snapshot(name, format: "ai")             = call("snapshot",   name: name, format: format)
    def wait_for(name, selector, timeout: 10)    = call("wait_for",   name: name, selector: selector, timeout: timeout)
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

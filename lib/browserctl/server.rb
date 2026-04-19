# frozen_string_literal: true

require "ferrum"
require "socket"
require "json"
require "fileutils"
require_relative "constants"

module Browserctl
  class Server
    def initialize(headless: true)
      FileUtils.mkdir_p(File.dirname(SOCKET_PATH))
      @browser   = Ferrum::Browser.new(headless: headless, timeout: 30)
      @pages     = {}
      @last_used = Time.now
      @mutex     = Mutex.new
    end

    def run
      write_pid
      FileUtils.rm_f(SOCKET_PATH)

      server = UNIXServer.new(SOCKET_PATH)
      File.chmod(0o600, SOCKET_PATH)
      $stdout.puts "browserd listening on #{SOCKET_PATH}"
      $stdout.flush

      idle_thread = Thread.new { watch_idle(server) }

      loop do
        client = server.accept
        Thread.new(client) { |c| handle(c) }
      end
    rescue SignalException
      # clean shutdown
    ensure
      idle_thread&.kill
      begin
        @browser.quit
      rescue StandardError
        nil
      end
      begin
        File.unlink(SOCKET_PATH)
      rescue StandardError
        nil
      end
      begin
        File.unlink(PID_PATH)
      rescue StandardError
        nil
      end
    end

    private

    def handle(socket)
      line = socket.gets
      return unless line

      @last_used = Time.now
      req = JSON.parse(line.chomp, symbolize_names: true)
      res = @mutex.synchronize { dispatch(req) }
      socket.puts(JSON.generate(res))
    rescue StandardError => e
      begin
        socket.puts(JSON.generate({ error: e.message }))
      rescue StandardError
        nil
      end
    ensure
      begin
        socket.close
      rescue StandardError
        nil
      end
    end

    def dispatch(req) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      case req[:cmd]
      when "open_page"
        name = req[:name]
        unless @pages[name]
          page = @browser.create_page
          page.go_to(req[:url]) if req[:url]
          @pages[name] = page
        end
        { ok: true, name: name }

      when "close_page"
        page = @pages.delete(req[:name])
        page&.close
        { ok: true }

      when "list_pages"
        { pages: @pages.keys }

      when "goto"
        with_page(req[:name]) do |p|
          p.go_to(req[:url])
          { ok: true, url: p.current_url }
        end

      when "snapshot"
        with_page(req[:name]) do |p|
          if req[:format] == "ai"
            { ok: true, snapshot: ai_snapshot(p) }
          else
            { ok: true, html: p.body }
          end
        end

      when "evaluate"
        with_page(req[:name]) { |p| { ok: true, result: p.evaluate(req[:expression]) } }

      when "fill"
        with_page(req[:name]) do |p|
          el = p.at_css(req[:selector])
          return { error: "selector not found: #{req[:selector]}" } unless el

          el.focus
          el.type(req[:value])
          { ok: true }
        end

      when "click"
        with_page(req[:name]) do |p|
          el = p.at_css(req[:selector])
          return { error: "selector not found: #{req[:selector]}" } unless el

          el.click
          { ok: true }
        end

      when "screenshot"
        with_page(req[:name]) do |p|
          path = req[:path] || "/tmp/browserctl_shot_#{req[:name]}_#{Time.now.to_i}.png"
          p.screenshot(path: path, full: req.fetch(:full, false))
          { ok: true, path: path }
        end

      when "wait_for"
        with_page(req[:name]) do |p|
          timeout  = req.fetch(:timeout, 10).to_f
          deadline = Time.now + timeout
          loop do
            break if p.at_css(req[:selector])
            if Time.now > deadline
              return { error: "wait_for timeout: selector '#{req[:selector]}' not found after #{timeout}s" }
            end

            sleep 0.2
          end
          { ok: true }
        end

      when "url"
        with_page(req[:name]) { |p| { ok: true, url: p.current_url } }

      when "ping"
        { ok: true, pid: Process.pid }

      when "shutdown"
        Process.kill("INT", Process.pid)
        { ok: true }

      else
        { error: "unknown command: #{req[:cmd]}" }
      end
    end

    def with_page(name)
      page = @pages[name]
      return { error: "no page named '#{name}'" } unless page

      yield page
    end

    def ai_snapshot(page)
      doc = Nokogiri::HTML(page.body)
      ref = 0
      interactable = %w[a button input select textarea [role=button] [role=link] [role=menuitem]]

      doc.css(interactable.join(",")).map do |el|
        ref += 1
        {
          ref: "e#{ref}",
          tag: el.name,
          text: el.text.strip.slice(0, 80),
          selector: css_path(el),
          attrs: el.attributes.transform_values(&:value).slice("type", "name", "placeholder", "href", "aria-label",
                                                               "role")
        }
      end
    end

    def css_path(node) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      parts = []
      while node && node.name != "html"
        id    = node["id"]
        klass = node["class"]&.split&.first
        seg   = node.name
        seg  += "##{id}"    if id && !id.empty?
        seg  += ".#{klass}" if klass && !klass.empty? && !id
        parts.unshift(seg)
        node = node.parent
      end
      parts.join(" > ")
    end

    def watch_idle(server)
      loop do
        sleep 60
        next unless Time.now - @last_used > IDLE_TTL

        $stdout.puts "browserd idle timeout, shutting down"
        begin
          server.close
        rescue StandardError
          nil
        end
        Process.kill("INT", Process.pid)
        break
      end
    end

    def write_pid
      File.write(PID_PATH, Process.pid.to_s)
    end
  end
end

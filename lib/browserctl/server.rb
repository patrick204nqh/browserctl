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
    end

    def run
      write_pid
      File.unlink(SOCKET_PATH) if File.exist?(SOCKET_PATH)

      server = UNIXServer.new(SOCKET_PATH)
      File.chmod(0o600, SOCKET_PATH)
      $stdout.puts "browserd listening on #{SOCKET_PATH}"
      $stdout.flush

      idle_thread = Thread.new { watch_idle(server) }

      loop do
        client = server.accept
        Thread.new(client) { |c| handle(c) }
      end
    rescue Interrupt, SignalException
      # clean shutdown
    ensure
      idle_thread&.kill
      @browser.quit rescue nil
      File.unlink(SOCKET_PATH) rescue nil
      File.unlink(PID_PATH)   rescue nil
    end

    private

    def handle(socket)
      line = socket.gets
      return unless line

      @last_used = Time.now
      req = JSON.parse(line.chomp, symbolize_names: true)
      res = dispatch(req)
      socket.puts(JSON.generate(res))
    rescue => e
      socket.puts(JSON.generate({ error: e.message })) rescue nil
    ensure
      socket.close rescue nil
    end

    def dispatch(req)
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
        with_page(req[:name]) { |p| p.go_to(req[:url]); { ok: true, url: p.current_url } }

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
          p.at_css(req[:selector])&.focus
          p.at_css(req[:selector])&.type(req[:value])
          { ok: true }
        end

      when "click"
        with_page(req[:name]) { |p| p.at_css(req[:selector])&.click; { ok: true } }

      when "screenshot"
        with_page(req[:name]) do |p|
          path = req[:path] || "/tmp/browserctl_shot_#{req[:name]}_#{Time.now.to_i}.png"
          p.screenshot(path: path, full: req.fetch(:full, false))
          { ok: true, path: path }
        end

      when "wait_for"
        with_page(req[:name]) do |p|
          timeout = req.fetch(:timeout, 10).to_f
          p.network.wait_for_idle(timeout: timeout)
          p.at_css(req[:selector]) # raises if absent
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
          ref:      "e#{ref}",
          tag:      el.name,
          text:     el.text.strip.slice(0, 80),
          selector: css_path(el),
          attrs:    el.attributes.transform_values(&:value).slice("type", "name", "placeholder", "href", "aria-label", "role")
        }
      end
    end

    def css_path(node)
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
        if Time.now - @last_used > IDLE_TTL
          $stdout.puts "browserd idle timeout, shutting down"
          server.close rescue nil
          Process.kill("INT", Process.pid)
          break
        end
      end
    end

    def write_pid
      File.write(PID_PATH, Process.pid.to_s)
    end
  end
end

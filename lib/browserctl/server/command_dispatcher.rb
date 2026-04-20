# frozen_string_literal: true

require_relative "snapshot_builder"
require_relative "page_session"

module Browserctl
  class CommandDispatcher
    COMMAND_MAP = {
      "open_page"  => :cmd_open_page,
      "close_page" => :cmd_close_page,
      "list_pages" => :cmd_list_pages,
      "goto"       => :cmd_goto,
      "snapshot"   => :cmd_snapshot,
      "evaluate"   => :cmd_evaluate,
      "fill"       => :cmd_fill,
      "click"      => :cmd_click,
      "screenshot" => :cmd_screenshot,
      "wait_for"   => :cmd_wait_for,
      "watch"      => :cmd_watch,
      "url"        => :cmd_url,
      "ping"       => :cmd_ping,
      "shutdown"   => :cmd_shutdown,
      "pause"      => :cmd_pause,
      "resume"     => :cmd_resume
    }.freeze

    SCREENSHOT_DIR  = File.expand_path("~/.browserctl/screenshots").freeze
    SCREENSHOT_EXTS = %w[.png .jpg .jpeg].freeze

    def initialize(pages, browser, snapshot_builder = SnapshotBuilder.new, global_mutex: Mutex.new)
      @pages            = pages
      @browser          = browser
      @snapshot_builder = snapshot_builder
      @global_mutex     = global_mutex
    end

    def dispatch(req)
      handler = COMMAND_MAP[req[:cmd]]
      return { error: "unknown command: #{req[:cmd]}" } unless handler

      Browserctl.logger.debug("#{req[:cmd]} #{req[:name]}")
      send(handler, req)
    end

    private

    def cmd_open_page(req)
      session = @global_mutex.synchronize do
        @pages[req[:name]] ||= PageSession.new(@browser.create_page)
      end
      session.page.go_to(req[:url]) if req[:url]
      { ok: true, name: req[:name] }
    end

    def cmd_close_page(req)
      session = @global_mutex.synchronize { @pages.delete(req[:name]) }
      session&.page&.close
      { ok: true }
    end

    def cmd_list_pages(_req)
      { pages: @global_mutex.synchronize { @pages.keys } }
    end

    def cmd_goto(req)
      with_page(req[:name]) do |session|
        session.page.go_to(req[:url])
        { ok: true, url: session.page.current_url, challenge: cloudflare_challenge?(session.page) }
      end
    end

    def cmd_snapshot(req)
      with_page(req[:name]) { |session| take_snapshot(session, req[:format], req[:diff]) }
    end

    def take_snapshot(session, format, diff)
      challenge = cloudflare_challenge?(session.page)

      unless format == "ai"
        return { ok: true, html: session.page.body, challenge: challenge }
      end

      snapshot = @snapshot_builder.call(session.page)
      registry = snapshot.to_h { |el| [el[:ref], el[:selector]] }

      prev = session.prev_snapshot
      session.ref_registry  = registry
      session.prev_snapshot = snapshot
      result = diff && prev ? compute_diff(prev, snapshot) : snapshot

      { ok: true, snapshot: result, challenge: challenge }
    end

    def compute_diff(prev, current)
      prev_by_sel = prev.to_h { |el| [el[:selector], el] }
      current.reject do |el|
        old = prev_by_sel[el[:selector]]
        old && old.slice(:text, :attrs) == el.slice(:text, :attrs)
      end
    end

    def cmd_evaluate(req)
      with_page(req[:name]) { |session| { ok: true, result: session.page.evaluate(req[:expression]) } }
    end

    def cmd_fill(req)
      with_page(req[:name]) do |session|
        sel = resolve_selector_from(session, req)
        return sel if sel.is_a?(Hash)

        type_into(session.page, sel, req[:value])
      end
    end

    def type_into(page, selector, value)
      el = page.at_css(selector)
      return { error: "selector not found: #{selector}" } unless el

      el.focus
      el.type(value)
      { ok: true }
    end

    def cmd_click(req)
      with_page(req[:name]) do |session|
        sel = resolve_selector_from(session, req)
        return sel if sel.is_a?(Hash)

        click_element(session.page, sel)
      end
    end

    def click_element(page, selector)
      el = page.at_css(selector)
      return { error: "selector not found: #{selector}" } unless el

      el.click
      { ok: true }
    end

    def cmd_screenshot(req)
      with_page(req[:name]) do |session|
        path = safe_screenshot_path(req[:path], req[:name])
        return path if path.is_a?(Hash)

        FileUtils.mkdir_p(File.dirname(path))
        session.page.screenshot(path: path, full: req.fetch(:full, false))
        { ok: true, path: path }
      end
    end

    def safe_screenshot_path(requested, page_name)
      if requested
        expanded = File.expand_path(requested)
        return { error: "path outside allowed directory (#{SCREENSHOT_DIR})" } \
          unless expanded.start_with?(SCREENSHOT_DIR)
        return { error: "invalid extension — use .png, .jpg, or .jpeg" } \
          unless SCREENSHOT_EXTS.include?(File.extname(expanded).downcase)

        expanded
      else
        name_safe = page_name.to_s.gsub(/[^a-zA-Z0-9_-]/, "_")
        File.join(SCREENSHOT_DIR, "browserctl_shot_#{name_safe}_#{Time.now.to_i}.png")
      end
    end

    def cmd_wait_for(req)
      with_page(req[:name]) { |session| wait_for_selector(session.page, req[:selector], req.fetch(:timeout, 10).to_f) }
    end

    def cmd_watch(req)
      with_page(req[:name]) do |session|
        result = wait_for_selector(session.page, req[:selector], req.fetch(:timeout, 30).to_f)
        result[:error] ? result : { ok: true, selector: req[:selector] }
      end
    end

    def wait_for_selector(page, selector, timeout)
      deadline = Time.now + timeout
      loop do
        found = page.at_css(selector)
        break { ok: true } if found
        break { error: "wait_for timeout: selector '#{selector}' not found after #{timeout}s" } if Time.now >= deadline

        sleep 0.2
      end
    end

    def cmd_url(req)
      with_page(req[:name]) { |session| { ok: true, url: session.page.current_url } }
    end

    def cmd_pause(req)
      session = @global_mutex.synchronize { @pages[req[:name]] }
      return { error: "no page named '#{req[:name]}'" } unless session

      session.mutex.synchronize { session.pause! }
      { ok: true, paused: true }
    end

    def cmd_resume(req)
      session = @global_mutex.synchronize { @pages[req[:name]] }
      return { error: "no page named '#{req[:name]}'" } unless session

      session.mutex.synchronize do
        session.resume!
        session.pause_cv.signal
      end
      { ok: true, paused: false }
    end

    def cmd_ping(_req) = { ok: true, pid: Process.pid }

    def cmd_shutdown(_req)
      Process.kill("INT", Process.pid)
      { ok: true }
    end

    def with_page(name)
      session = @global_mutex.synchronize { @pages[name] }
      return { error: "no page named '#{name}'" } unless session

      session.mutex.synchronize do
        session.pause_cv.wait(session.mutex) while session.paused?
        yield session
      end
    end

    CLOUDFLARE_SIGNALS = [
      "cf-challenge-running",
      "cf_chl_opt",
      "__cf_chl_f_tk",
      "Just a moment..."
    ].freeze

    def cloudflare_challenge?(page)
      url  = page.current_url.to_s
      body = page.body.to_s
      url.include?("challenge-platform") ||
        CLOUDFLARE_SIGNALS.any? { |sig| body.include?(sig) }
    end

    def resolve_selector_from(session, req)
      return req[:selector] if req[:selector]
      return { error: "selector or ref required" } unless req[:ref]

      session.ref_registry[req[:ref]] || { error: "ref '#{req[:ref]}' not found — run snap first" }
    end
  end
end

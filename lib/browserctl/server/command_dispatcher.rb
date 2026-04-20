# frozen_string_literal: true

require_relative "snapshot_builder"

module Browserctl
  class CommandDispatcher
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
      "url" => :cmd_url,
      "ping" => :cmd_ping,
      "shutdown" => :cmd_shutdown
    }.freeze

    def initialize(pages, browser, snapshot_builder = SnapshotBuilder.new, mutex: Mutex.new)
      @pages          = pages
      @browser        = browser
      @snapshot       = snapshot_builder
      @mutex          = mutex
      @ref_registries = {}
      @prev_snapshots = {}
    end

    def dispatch(req)
      handler = COMMAND_MAP[req[:cmd]]
      return { error: "unknown command: #{req[:cmd]}" } unless handler

      Browserctl.logger.debug("#{req[:cmd]} #{req[:name]}")
      send(handler, req)
    end

    private

    def cmd_open_page(req)
      page = @mutex.synchronize { @pages[req[:name]] } || begin
        new_page = @browser.create_page
        @mutex.synchronize { @pages[req[:name]] ||= new_page }
      end
      page.go_to(req[:url]) if req[:url]
      { ok: true, name: req[:name] }
    end

    def cmd_close_page(req)
      @mutex.synchronize { @pages.delete(req[:name]) }&.close
      { ok: true }
    end

    def cmd_list_pages(_req)
      { pages: @mutex.synchronize { @pages.keys } }
    end

    def cmd_goto(req)
      with_page(req[:name]) do |p|
        p.go_to(req[:url])
        { ok: true, url: p.current_url }
      end
    end

    def cmd_snapshot(req)
      with_page(req[:name]) { |p| take_snapshot(req[:name], p, req[:format], req[:diff]) }
    end

    def take_snapshot(name, page, format, diff)
      return { ok: true, html: page.body } unless format == "ai"

      snapshot = @snapshot.call(page)
      registry = snapshot.each_with_object({}) { |el, h| h[el[:ref]] = el[:selector] }

      result = @mutex.synchronize do
        prev = @prev_snapshots[name]
        @ref_registries[name] = registry
        @prev_snapshots[name] = snapshot
        (diff && prev) ? compute_diff(prev, snapshot) : snapshot
      end

      { ok: true, snapshot: result }
    end

    def compute_diff(prev, current)
      prev_by_sel = prev.each_with_object({}) { |el, h| h[el[:selector]] = el }
      current.reject do |el|
        old = prev_by_sel[el[:selector]]
        old && old.slice(:text, :attrs) == el.slice(:text, :attrs)
      end
    end

    def cmd_evaluate(req)
      with_page(req[:name]) { |p| { ok: true, result: p.evaluate(req[:expression]) } }
    end

    def cmd_fill(req)
      sel = resolve_selector(req[:name], req)
      return sel if sel.is_a?(Hash)
      with_page(req[:name]) { |p| type_into(p, sel, req[:value]) }
    end

    def type_into(page, selector, value)
      el = page.at_css(selector)
      return { error: "selector not found: #{selector}" } unless el

      el.focus
      el.type(value)
      { ok: true }
    end

    def cmd_click(req)
      sel = resolve_selector(req[:name], req)
      return sel if sel.is_a?(Hash)
      with_page(req[:name]) { |p| click_element(p, sel) }
    end

    def click_element(page, selector)
      el = page.at_css(selector)
      return { error: "selector not found: #{selector}" } unless el

      el.click
      { ok: true }
    end

    def cmd_screenshot(req)
      with_page(req[:name]) do |p|
        path = req[:path] || "/tmp/browserctl_shot_#{req[:name]}_#{Time.now.to_i}.png"
        p.screenshot(path: path, full: req.fetch(:full, false))
        { ok: true, path: path }
      end
    end

    def cmd_wait_for(req)
      with_page(req[:name]) { |p| wait_for_selector(p, req[:selector], req.fetch(:timeout, 10).to_f) }
    end

    def wait_for_selector(page, selector, timeout)
      deadline = Time.now + timeout
      sleep 0.2 until (found = page.at_css(selector)) || Time.now > deadline
      found ? { ok: true } : { error: "wait_for timeout: selector '#{selector}' not found after #{timeout}s" }
    end

    def cmd_url(req)
      with_page(req[:name]) { |p| { ok: true, url: p.current_url } }
    end

    def cmd_ping(_req)
      { ok: true, pid: Process.pid }
    end

    def cmd_shutdown(_req)
      Process.kill("INT", Process.pid)
      { ok: true }
    end

    def with_page(name)
      page = @mutex.synchronize { @pages[name] }
      return { error: "no page named '#{name}'" } unless page

      yield page
    end

    def resolve_selector(name, req)
      return req[:selector] if req[:selector]
      return { error: "selector or ref required" } unless req[:ref]

      sel = @mutex.synchronize { @ref_registries.dig(name, req[:ref]) }
      sel || { error: "ref '#{req[:ref]}' not found — run snap first" }
    end
  end
end

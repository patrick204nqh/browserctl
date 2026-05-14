# frozen_string_literal: true

require_relative "page_driver"

module Browserctl
  module Driver
    # The only {PageDriver} implementation v0.15 ships. Wraps a Ferrum page
    # (or {CDPPage} delegator over one) and forwards each interface method to
    # the underlying Ferrum API. Intentionally dumb — no caching, no policy,
    # no logging. Anything beyond plain forwarding belongs in the handler or
    # in a dedicated wrapper, not here.
    class FerrumPageDriver
      include PageDriver

      # @return [Object] the underlying Ferrum/CDP page. Exposed for callers
      #   that still bridge through Ferrum-typed APIs (currently only the CDP
      #   driver's `devtools_info`). New handler code must not use this.
      attr_reader :raw_page

      def initialize(page)
        @raw_page = page
      end

      def go_to(url) = @raw_page.go_to(url)
      def current_url = @raw_page.current_url
      def body = @raw_page.body
      def evaluate(expression) = @raw_page.evaluate(expression)
      def at_css(selector) = @raw_page.at_css(selector)
      def screenshot(path:, full: false) = @raw_page.screenshot(path: path, full: full)
      def activate = @raw_page.activate
      def close = @raw_page.close
      def on(event, &) = @raw_page.on(event, &)
      def off(event, id) = @raw_page.off(event, id)
      def keyboard_down(key) = @raw_page.keyboard.down(key)
      def keyboard_up(key) = @raw_page.keyboard.up(key)
      def mouse_move(x:, y:) = @raw_page.mouse.move(x: x, y: y) # rubocop:disable Naming/MethodParameterName
      def cookies_all = @raw_page.cookies.all
      def cookies_set(**) = @raw_page.cookies.set(**)
      def cookies_clear = @raw_page.cookies.clear
      def target_id = @raw_page.target_id
    end
  end
end

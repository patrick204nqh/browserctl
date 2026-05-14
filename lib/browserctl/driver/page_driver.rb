# frozen_string_literal: true

module Browserctl
  module Driver
    # PageDriver is the interface every handler in `lib/browserctl/server/handlers/`
    # talks to instead of touching a raw Ferrum page. It exists so unit tests can
    # swap in a `FakePageDriver` (see `spec/support/fake_page_driver.rb`) without
    # spawning a real browser.
    #
    # This module is intentionally a thin contract: Ruby has no real interfaces,
    # so the implementation is duck-typed. The method list below is the entire
    # public surface handlers may use. New entries here require a corresponding
    # implementation in {FerrumPageDriver} **and** the test double, plus a
    # handler that justifies them — do not add methods speculatively.
    #
    # Element-returning methods (currently only {#at_css}) return whatever the
    # underlying driver returns. The fake driver returns stub objects with
    # matching duck-typed methods (`focus`, `type`, `click`, `evaluate`,
    # `select_file`). Handlers should treat these as opaque element handles.
    #
    # PageDriver lives in the **Extension** zone of the public surface
    # (see `docs/reference/api-stability.md`). It is a testing seam, not an
    # invitation to ship a non-Ferrum backend — that path is explicitly a
    # non-goal of v0.15 (`docs/plans/v0.15-lock.md`).
    module PageDriver
      # Navigate the page to the given URL. Blocks until load completes.
      # @param url [String]
      def go_to(url) = raise NotImplementedError

      # @return [String] the current top-frame URL
      def current_url = raise NotImplementedError

      # @return [String] the current page body HTML
      def body = raise NotImplementedError

      # Evaluate a JS expression in the page context.
      # @param expression [String]
      # @return [Object] the JSON-decoded result
      def evaluate(expression) = raise NotImplementedError

      # Find the first element matching the CSS selector.
      # @param selector [String]
      # @return [Object, nil] an element handle (duck-typed: `focus`, `type`,
      #   `click`, `evaluate`, `select_file`) or nil if no match
      def at_css(selector) = raise NotImplementedError

      # Capture a screenshot to disk.
      # @param path [String]
      # @param full [Boolean]
      def screenshot(path:, full: false) = raise NotImplementedError

      # Bring the page tab to the foreground (headed mode only).
      def activate = raise NotImplementedError

      # Close the underlying page/tab.
      def close = raise NotImplementedError

      # Subscribe to a page event (currently only `:dialog`).
      # @return [Object] a subscription id usable with {#off}
      def on(event, &) = raise NotImplementedError

      # Remove a subscription created by {#on}.
      def off(event, id) = raise NotImplementedError

      # Press a key down. Pair with {#keyboard_up}.
      def keyboard_down(key) = raise NotImplementedError

      # Release a key.
      def keyboard_up(key) = raise NotImplementedError

      # Move the mouse pointer to viewport coordinates.
      def mouse_move(x:, y:) = raise NotImplementedError # rubocop:disable Naming/MethodParameterName

      # @return [Hash{String => Object}] all cookies for the page, keyed by
      #   cookie name, with each value responding to `to_h`.
      def cookies_all = raise NotImplementedError

      # Set a cookie. Accepts `name:`, `value:`, `domain:`, `path:`, and any
      # of `httponly:`, `secure:`, `expires:`.
      def cookies_set(**) = raise NotImplementedError

      # Clear every cookie on the page.
      def cookies_clear = raise NotImplementedError

      # Underlying CDP target id; used by the devtools handler. Backends that
      # do not expose CDP should raise.
      def target_id = raise NotImplementedError
    end
  end
end

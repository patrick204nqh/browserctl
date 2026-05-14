# frozen_string_literal: true

require "browserctl/driver/page_driver"

module Browserctl
  module Testing
    # In-memory test double for {Browserctl::Driver::PageDriver}. Stateful
    # enough to let handlers exercise their full happy path without spawning
    # a browser. Pair with {FakeElement} for `at_css` calls.
    #
    # Each call is recorded on `#calls` so specs can assert against the
    # interaction trace. Use `stub_evaluate` to register canned return values
    # for `evaluate(expression)`, and `register_element(selector, element)` to
    # wire up specific selector → element mappings.
    class FakePageDriver
      include Browserctl::Driver::PageDriver

      attr_reader :calls, :cookies_store
      attr_accessor :current_url, :body, :target_id

      def initialize(current_url: "https://example.com/", body: "<html></html>")
        @current_url   = current_url
        @body          = body
        @target_id     = "fake-target-id"
        @calls         = []
        @evaluate_stubs = {}
        @evaluate_default = nil
        @elements      = {}
        @cookies_store = {}
        @event_subs    = Hash.new { |h, k| h[k] = {} }
        @next_sub_id   = 0
      end

      # --- evaluate stubbing ---

      def stub_evaluate(expression, result)
        @evaluate_stubs[expression] = result
      end

      def stub_evaluate_default(result)
        @evaluate_default = result
      end

      # --- element registration ---

      def register_element(selector, element)
        @elements[selector] = element
      end

      # --- PageDriver interface ---

      def go_to(url)
        record(:go_to, url)
        @current_url = url
      end

      def evaluate(expression)
        record(:evaluate, expression)
        return @evaluate_stubs[expression] if @evaluate_stubs.key?(expression)

        @evaluate_default
      end

      def at_css(selector)
        record(:at_css, selector)
        @elements[selector]
      end

      def screenshot(path:, full: false)
        record(:screenshot, path, full)
        :screenshot_taken
      end

      def activate
        record(:activate)
      end

      def close
        record(:close)
      end

      def on(event, &block)
        id = (@next_sub_id += 1)
        @event_subs[event][id] = block
        record(:on, event, id)
        id
      end

      def off(event, id)
        record(:off, event, id)
        @event_subs[event].delete(id)
      end

      def keyboard_down(key)
        record(:keyboard_down, key)
      end

      def keyboard_up(key)
        record(:keyboard_up, key)
      end

      def mouse_move(x:, y:) # rubocop:disable Naming/MethodParameterName
        record(:mouse_move, x, y)
      end

      def cookies_all
        @cookies_store
      end

      def cookies_set(**opts)
        name = opts[:name]
        @cookies_store[name] = FakeCookie.new(opts)
        record(:cookies_set, opts)
      end

      def cookies_clear
        record(:cookies_clear)
        @cookies_store.clear
      end

      # --- helpers ---

      # Trigger every registered handler for an event with a fake dialog/etc.
      def emit(event, payload)
        @event_subs[event].each_value { |blk| blk.call(payload) }
      end

      def calls_for(method_name)
        @calls.select { |c| c.first == method_name }
      end

      private

      def record(method, *args)
        @calls << [method, *args]
      end

      # Cookie struct that responds to `to_h` like Ferrum's cookies do.
      class FakeCookie
        def initialize(attrs)
          @attrs = attrs.dup
        end

        def to_h = @attrs.dup
      end
    end

    # Minimal element double that handlers exercise via `at_css(...)`.
    # Records every method invocation on `#calls`.
    class FakeElement
      attr_reader :calls

      def initialize
        @calls = []
      end

      def focus           = @calls << [:focus]
      def type(value)     = @calls << [:type, value]
      def click           = @calls << [:click]
      def evaluate(expr)  = (@calls << [:evaluate, expr]) && nil
      def select_file(path) = @calls << [:select_file, path]
    end
  end
end

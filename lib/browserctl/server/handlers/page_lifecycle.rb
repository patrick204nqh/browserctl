# frozen_string_literal: true

require_relative "../../driver/ferrum_page_driver"

module Browserctl
  class CommandDispatcher
    module Handlers
      # Page-lifecycle handlers are intrinsically registry-wide: they
      # add to, remove from, or enumerate the `@pages` registry. They
      # legitimately bypass `with_page` and hold `@global_mutex` directly.
      module PageLifecycle
        private

        def cmd_page_open(req)
          # registry-wide: adds an entry to @pages, needs @global_mutex.
          session = @global_mutex.synchronize do
            @pages[req[:name]] ||= PageSession.new(Browserctl::Driver::FerrumPageDriver.new(@driver.create_page))
          end
          session.driver.go_to(req[:url]) if req[:url]
          { ok: true, name: req[:name] }
        end

        def cmd_page_close(req)
          # registry-wide: removes an entry from @pages, needs @global_mutex.
          session = @global_mutex.synchronize { @pages.delete(req[:name]) }
          session&.driver&.close
          { ok: true }
        end

        def cmd_page_list(_req)
          # registry-wide read: enumerates @pages keys (no per-page state).
          { pages: @global_mutex.synchronize { @pages.keys } }
        end

        def cmd_page_focus(req)
          return { error: "page focus requires headed mode — start browserd with --headed" } unless @driver.headed?

          with_page(req[:name]) do |session|
            session.driver.activate
            { ok: true }
          end
        end
      end
    end
  end
end

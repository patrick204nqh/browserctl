# frozen_string_literal: true

module Browserctl
  class CommandDispatcher
    module Handlers
      module PageLifecycle
        private

        def cmd_page_open(req)
          session = @global_mutex.synchronize do
            @pages[req[:name]] ||= PageSession.new(@browser.create_page)
          end
          session.page.go_to(req[:url]) if req[:url]
          { ok: true, name: req[:name] }
        end

        def cmd_page_close(req)
          session = @global_mutex.synchronize { @pages.delete(req[:name]) }
          session&.page&.close
          { ok: true }
        end

        def cmd_page_list(_req)
          { pages: @global_mutex.synchronize { @pages.keys } }
        end
      end
    end
  end
end

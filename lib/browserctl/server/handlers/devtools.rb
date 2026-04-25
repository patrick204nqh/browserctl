# frozen_string_literal: true

module Browserctl
  class CommandDispatcher
    module Handlers
      module DevTools
        private

        def cmd_inspect(req)
          session = @global_mutex.synchronize { @pages[req[:name]] }
          return { error: "no page named '#{req[:name]}'" } unless session

          port      = @browser.process.port
          target_id = session.page.target_id
          devtools_url = "http://127.0.0.1:#{port}/devtools/inspector.html" \
                         "?ws=127.0.0.1:#{port}/devtools/page/#{target_id}"
          { ok: true, devtools_url: devtools_url }
        end
      end
    end
  end
end

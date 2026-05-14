# frozen_string_literal: true

module Browserctl
  class CommandDispatcher
    module Handlers
      module DevTools
        private

        def cmd_devtools(req)
          return { error: "devtools is not supported by this driver" } unless @driver.supports?(:devtools)

          session = @global_mutex.synchronize { @pages[req[:name]] }
          return { error: "no page named '#{req[:name]}'" } unless session

          info      = @driver.devtools_info(session.driver)
          port      = info[:port]
          target_id = info[:target_id]
          devtools_url = "http://127.0.0.1:#{port}/devtools/inspector.html" \
                         "?ws=127.0.0.1:#{port}/devtools/page/#{target_id}"
          { ok: true, devtools_url: devtools_url }
        end
      end
    end
  end
end

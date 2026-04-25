# frozen_string_literal: true

module Browserctl
  class CommandDispatcher
    module Handlers
      module Hitl
        private

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
      end
    end
  end
end

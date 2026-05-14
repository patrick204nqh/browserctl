# frozen_string_literal: true

module Browserctl
  class CommandDispatcher
    module Handlers
      # HITL pause/resume cannot route through `with_page` because `with_page`
      # acquires `session.mutex` and waits on `session.pause_cv` while paused.
      # Pause sets that flag; resume signals the CV. Reentering `with_page`
      # would deadlock — resume would never get the lock to clear the flag.
      # So these handlers look up the session under `@global_mutex` directly,
      # then manage `session.mutex` / `pause_cv` themselves.
      module Hitl
        private

        def cmd_pause(req)
          # registry lookup: HITL manages session.mutex/pause_cv directly,
          # cannot reenter with_page (would deadlock against pause_cv wait).
          session = @global_mutex.synchronize { @pages[req[:name]] }
          return { error: "no page named '#{req[:name]}'" } unless session

          session.mutex.synchronize { session.pause! }
          Browserctl.logger.info("HITL pause: #{req[:message]}") if req[:message]
          { ok: true, paused: true, message: req[:message] }
        end

        def cmd_resume(req)
          # registry lookup: HITL manages session.mutex/pause_cv directly,
          # cannot reenter with_page (would deadlock against pause_cv wait).
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

# frozen_string_literal: true

module Browserctl
  class CommandDispatcher
    module Handlers
      module Session
        private

        # Saves current browser state (cookies + localStorage + open pages) to a named session.
        # Full implementation in commit 6 — stub raises until then.
        def cmd_session_save(req)
          raise NotImplementedError, "session_save not yet implemented"
        end

        # Restores a previously saved session into the running daemon.
        # Full implementation in commit 6 — stub raises until then.
        def cmd_session_load(req)
          raise NotImplementedError, "session_load not yet implemented"
        end

        # Lists all saved sessions from ~/.browserctl/sessions/.
        # Full implementation in commit 6 — stub raises until then.
        def cmd_session_list(_req)
          raise NotImplementedError, "session_list not yet implemented"
        end

        # Permanently deletes a named session directory.
        # Full implementation in commit 6 — stub raises until then.
        def cmd_session_delete(req)
          raise NotImplementedError, "session_delete not yet implemented"
        end
      end
    end
  end
end

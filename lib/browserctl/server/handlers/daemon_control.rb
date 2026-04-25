# frozen_string_literal: true

module Browserctl
  class CommandDispatcher
    module Handlers
      module DaemonControl
        private

        def cmd_ping(_req) = { ok: true, pid: Process.pid, protocol_version: PROTOCOL_VERSION }

        def cmd_shutdown(_req)
          Process.kill("INT", Process.pid)
          { ok: true }
        end

        def cmd_store(req)
          @kv_mutex.synchronize { @kv_store[req[:key].to_s] = req[:value] }
          { ok: true }
        end

        def cmd_fetch(req)
          key = req[:key].to_s
          found = @kv_mutex.synchronize { @kv_store.key?(key) ? { ok: true, value: @kv_store[key] } : nil }
          found || { error: "key '#{key}' not found", code: "key_not_found" }
        end
      end
    end
  end
end

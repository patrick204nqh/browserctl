# frozen_string_literal: true

require_relative "workflow/recovery_manager"

module Browserctl
  # Persistence-and-state DSL mixed into {WorkflowContext}. {FlowContext}
  # does NOT mix this in — that absence is the structural enforcement of
  # the doctrinal split: flows return state, workflows share state through
  # the daemon-backed `store`/`fetch` and `.bctl` bundles.
  #
  # Hosts must expose `@client` and may expose `@replay_context` (for the
  # selector-rematch fallback used elsewhere). Auth-required recovery is
  # delegated to {Workflow::RecoveryManager}, which calls back into the
  # host's `invoke` so flows bound to a saved bundle can rotate
  # credentials transparently.
  module ContextualPersistence
    def store(key, value)
      res = @client.store(key.to_s, value)
      raise WorkflowError, res[:error] if res[:error]

      value
    end

    def fetch(key)
      res = @client.fetch(key.to_s)
      raise WorkflowError, res[:error] if res[:error]

      res[:value]
    end

    # Persists the daemon's current cookies + storage as a .bctl bundle.
    # Optional flow binding lets `load_state` auto-rotate when the bundle
    # is detected as needing authentication.
    def save_state(name, flow: nil, origins: nil, encrypt: false)
      passphrase = encrypt ? ENV.fetch("BROWSERCTL_STATE_PASSPHRASE", nil) : nil
      res = @client.state_save(name.to_s,
                               flow: flow&.to_s, origins: origins, passphrase: passphrase)
      raise WorkflowError, res[:error] if res[:error]

      res
    end

    # Restores a .bctl bundle. When the daemon detects AUTH_REQUIRED before
    # applying (e.g. expired cookies in the payload), this delegates to
    # {Workflow::RecoveryManager}, which rotates the bound flow and retries
    # — no caller code change required.
    #
    # @param on_auth_required [Proc, nil] override the auto-rotate path. The
    #   block runs in the workflow context, in lieu of invoking the manifest's
    #   bound flow. Use this when the recovery procedure is bespoke.
    def load_state(name, on_auth_required: nil)
      res = @client.state_load(name.to_s)
      return res unless Workflow::RecoveryManager.auth_required?(res)

      Workflow::RecoveryManager.new(self).recover(name.to_s, res, on_auth_required: on_auth_required)
    end
  end
end

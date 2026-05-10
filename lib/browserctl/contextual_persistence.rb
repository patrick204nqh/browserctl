# frozen_string_literal: true

module Browserctl
  # Persistence-and-state DSL mixed into {WorkflowContext}. {FlowContext}
  # does NOT mix this in — that absence is the structural enforcement of
  # the doctrinal split: flows return state, workflows share state through
  # the daemon-backed `store`/`fetch` and `.bctl` bundles.
  #
  # Hosts must expose `@client` and may expose `@replay_context` (for the
  # selector-rematch fallback used elsewhere). Auth-required recovery
  # delegates back to the host's `invoke` so flows bound to a saved
  # bundle can rotate credentials transparently.
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
    # applying (e.g. expired cookies in the payload), this rotates the bound
    # flow and retries — no caller code change required.
    #
    # @param on_auth_required [Proc, nil] override the auto-rotate path. The
    #   block runs in the workflow context, in lieu of invoking the manifest's
    #   bound flow. Use this when the recovery procedure is bespoke.
    def load_state(name, on_auth_required: nil)
      res = @client.state_load(name.to_s)
      return res unless auth_required_response?(res)

      recover_auth_required_state(name.to_s, res, on_auth_required)
    end

    private

    def auth_required_response?(res)
      (res[:code] || res["code"]) == "AUTH_REQUIRED"
    end

    def recover_auth_required_state(name, initial_res, on_auth_required)
      if on_auth_required
        on_auth_required.call
      else
        flow_name = initial_res[:suggested_flow] || initial_res["suggested_flow"]
        unless flow_name && !flow_name.to_s.empty?
          raise WorkflowError,
                "state '#{name}' needs auth but bundle has no bound flow — " \
                "save with `save_state('#{name}', flow: :NAME)` or pass on_auth_required:"
        end

        # Match the daemon's `state load` preflight: it auth-checks the first
        # open page (insertion order). Passing that same name to the flow
        # gives stdlib flows a `page` proxy to drive (oauth_github reads
        # `page.url`, totp_2fa calls `page.fill`, etc.). Falls back to no
        # page only when nothing is open — `state_save` would have errored
        # earlier in that case, so this is a defence-in-depth nil.
        invoke(flow_name, page: first_open_page)
      end

      after_save = @client.state_save(name)
      raise WorkflowError, after_save[:error] if after_save[:error]

      retry_res = @client.state_load(name, skip_auth_check: true)
      raise WorkflowError, retry_res[:error] if retry_res[:error]

      retry_res.merge(rotated: true)
    end

    def first_open_page
      res = @client.page_list
      pages = res[:pages] || res["pages"] || []
      pages.first
    end
  end
end

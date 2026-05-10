# frozen_string_literal: true

module Browserctl
  module Workflow
    # Owns the AUTH_REQUIRED recovery state machine for `load_state`.
    #
    # When the daemon reports AUTH_REQUIRED on a `state_load` (e.g. expired
    # cookies in the bundle), the manager either runs the bound flow or
    # the caller-provided override, re-saves the bundle, and reloads it
    # with `skip_auth_check: true`.
    #
    # Decoupled from {ContextualPersistence} so the multi-step recovery
    # logic has a dedicated home and a dedicated spec. The host context
    # only needs to expose `client` (for daemon RPCs) and `invoke` (for
    # running the bound flow); see {ContextualPersistence#load_state}.
    class RecoveryManager
      AUTH_REQUIRED_CODE = "AUTH_REQUIRED"

      # @param context [#client, #invoke] a workflow context exposing
      #   the daemon client and an `invoke(flow_name, page:)` entry point.
      def initialize(context)
        @context = context
      end

      # True when `res` is the daemon's AUTH_REQUIRED preflight signal.
      def self.auth_required?(res)
        (res[:code] || res["code"]) == AUTH_REQUIRED_CODE
      end

      # Run recovery for `state_name` given the daemon's initial AUTH_REQUIRED
      # response. Returns the merged retry result (with `rotated: true`) or
      # raises {WorkflowError} when no flow is bound and no override is
      # supplied, or when the post-rotation reload still fails.
      #
      # @param state_name      [String]  the bundle name being loaded
      # @param initial_res     [Hash]    the original AUTH_REQUIRED response
      # @param on_auth_required [Proc, nil] optional override; when given,
      #   it runs in lieu of invoking the suggested flow.
      def recover(state_name, initial_res, on_auth_required: nil)
        if on_auth_required
          on_auth_required.call
        else
          invoke_bound_flow(state_name, initial_res)
        end

        rotate_and_reload(state_name)
      end

      private

      attr_reader :context

      def invoke_bound_flow(state_name, initial_res)
        flow_name = initial_res[:suggested_flow] || initial_res["suggested_flow"]
        if flow_name.nil? || flow_name.to_s.empty?
          raise WorkflowError,
                "state '#{state_name}' needs auth but bundle has no bound flow — " \
                "save with `save_state('#{state_name}', flow: :NAME)` or pass on_auth_required:"
        end

        # Match the daemon's `state load` preflight: it auth-checks the first
        # open page (insertion order). Passing that same name to the flow
        # gives stdlib flows a `page` proxy to drive (oauth_github reads
        # `page.url`, totp_2fa calls `page.fill`, etc.). Falls back to no
        # page only when nothing is open — `state_save` would have errored
        # earlier in that case, so this is a defence-in-depth nil.
        context.invoke(flow_name, page: first_open_page)
      end

      def rotate_and_reload(state_name)
        after_save = context.client.state_save(state_name)
        raise WorkflowError, after_save[:error] if after_save[:error]

        retry_res = context.client.state_load(state_name, skip_auth_check: true)
        raise WorkflowError, retry_res[:error] if retry_res[:error]

        retry_res.merge(rotated: true)
      end

      def first_open_page
        res = context.client.page_list
        pages = res[:pages] || res["pages"] || []
        pages.first
      end
    end
  end
end

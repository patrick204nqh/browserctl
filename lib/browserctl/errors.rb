# frozen_string_literal: true

module Browserctl
  # Base error class for all browserctl daemon errors.
  # Subclasses carry a machine-readable `code` that appears in wire responses.
  # @attr_reader code [String] machine-readable error code
  class Error < StandardError
    def self.default_code = "error"

    attr_reader :code

    def initialize(msg = nil, code: self.class.default_code)
      @code = code
      super(msg)
    end
  end

  class PageNotFound     < Error; def self.default_code = "page_not_found"     end
  class SelectorNotFound < Error; def self.default_code = "selector_not_found" end
  class RefNotFound      < Error; def self.default_code = "ref_not_found"      end
  class PathNotAllowed   < Error; def self.default_code = "path_not_allowed"   end
  class DomainNotAllowed < Error; def self.default_code = "domain_not_allowed" end
  class TimeoutError     < Error; def self.default_code = "timeout"            end
  class KeyNotFound < Error; def self.default_code = "key_not_found" end
  class DaemonUnavailableError < Error; def self.default_code = "daemon_unavailable" end
  class BrowserNotFound < Error; def self.default_code = "browser_not_found" end

  # Raised when the daemon detects that the current page needs authentication —
  # the canonical signal that a workflow's `load_state` should rotate the bound
  # flow. Carries the bundle name (when a state load was in progress) and a
  # suggested flow (from the bundle manifest) so callers can recover without
  # additional lookups. The CLI maps this code to exit status 7.
  class AuthRequiredError < Error
    def self.default_code = "AUTH_REQUIRED"

    AUTH_REQUIRED_EXIT_CODE = 7

    attr_reader :state, :suggested_flow, :reason

    def initialize(msg = "authentication required", state: nil, suggested_flow: nil, reason: nil)
      super(msg)
      @state          = state
      @suggested_flow = suggested_flow
      @reason         = reason
    end

    def to_response
      {
        error: message,
        code: self.class.default_code,
        state: state,
        suggested_flow: suggested_flow,
        reason: reason
      }.compact
    end
  end

  class WorkflowError < Error; def self.default_code = "workflow_error" end
  class SecretResolverError < WorkflowError; def self.default_code = "secret_resolver_error" end

  class FlowError < WorkflowError; def self.default_code = "flow_error" end
  class FlowParamError < FlowError; def self.default_code = "flow_param_error" end
  class FlowPreconditionError < FlowError; def self.default_code = "flow_precondition_failed" end
  class FlowStepError < FlowError; def self.default_code = "flow_step_failed" end
  class FlowPostconditionError < FlowError; def self.default_code = "flow_postcondition_failed" end

  # Raised when a persisted artifact (bundle, recording, workflow, etc.) has a
  # `version:` header that this build does not know how to read. The full error
  # code taxonomy lands in WS-2 (PR #7); this class is a forward-reference stub
  # so WS-1 PRs can already raise the canonical code.
  class ProtocolMismatch < Error; def self.default_code = "PROTOCOL_MISMATCH" end
end

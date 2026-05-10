# frozen_string_literal: true

require_relative "../../errors"

module Browserctl
  class CommandDispatcher
    module Handlers
      # Centralised structured-error builder for daemon JSON-RPC responses.
      # Each handler returns `{ error:, code:, context:, suggested_action: }`
      # for any failure carrying a stable {Browserctl::Error::Codes} code.
      module ErrorPayload
        # @param code [String] a SCREAMING_SNAKE code from {Codes}
        # @param message [String] human-readable error
        # @param context [Hash] free-form structured fields (selector, path, ...)
        # @return [Hash{Symbol => Object}]
        def error_payload(code:, message:, context: {})
          {
            error: message,
            code: code,
            context: context,
            suggested_action: Browserctl::Error::SuggestedActions.for(code)
          }
        end
      end
    end
  end
end

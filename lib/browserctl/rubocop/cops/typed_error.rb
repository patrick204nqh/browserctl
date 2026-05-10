# frozen_string_literal: true

require "rubocop"

module RuboCop
  module Cop
    module Browserctl
      # Enforces that any explicit `code:` keyword passed to a `raise` of a
      # `Browserctl::*` error refers to a constant from
      # `Browserctl::Error::Codes` rather than a free-form string literal.
      #
      # Subclasses with their own `default_code` are trusted (the cop does not
      # try to statically resolve `default_code` across files); the contract
      # is enforced by the unit test suite. This cop's job is to catch the
      # specific failure mode of inlining a stale snake_case code at the
      # raise site and bypassing the canonical enum.
      #
      # @example
      #   # bad — string literal that isn't a Codes constant
      #   raise Browserctl::Error, "state expired", code: "state_expired"
      #
      #   # good — Codes constant reference
      #   raise Browserctl::Error, "state expired",
      #         code: Browserctl::Error::Codes::STATE_EXPIRED
      #
      #   # good — typed subclass relies on its own default_code
      #   raise Browserctl::SelectorNotFound, "no such selector"
      #
      # The pattern is intentionally narrow. The full default_code-vs-Codes
      # reconciliation lives in `lib/browserctl/errors.rb` and is covered by
      # `spec/unit/errors_spec.rb`.
      class TypedError < RuboCop::Cop::Base
        MSG = "Browserctl raise: `code:` must reference Browserctl::Error::Codes::* — " \
              "got string literal %<value>p. See lib/browserctl/error/codes.rb."

        VALID_CODES = %w[
          AUTH_REQUIRED
          SELECTOR_NOT_FOUND
          STATE_EXPIRED
          SECRET_RESOLUTION_FAILED
          DAEMON_UNREACHABLE
          PROTOCOL_MISMATCH
        ].freeze

        # Matches `raise Browserctl::Foo, ..., code: <value>` and yields the
        # `code:` value node.
        def_node_matcher :browserctl_raise_with_code, <<~PATTERN
          (send nil? :raise
            (const (const nil? :Browserctl) _)
            ...
            (hash <(pair (sym :code) $_) ...>))
        PATTERN

        def on_send(node)
          return unless node.method?(:raise)

          browserctl_raise_with_code(node) do |code_value|
            next unless code_value.str_type?

            value = code_value.value
            next if VALID_CODES.include?(value)

            add_offense(code_value, message: format(MSG, value: value))
          end
        end
      end
    end
  end
end

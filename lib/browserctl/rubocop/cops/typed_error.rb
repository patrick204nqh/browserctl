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
      # specific failure mode of inlining a stale code string at the raise
      # site and bypassing the canonical enum.
      #
      # @example
      #   # bad — any string literal, even one that happens to match a
      #   # canonical code today, drifts when the enum is renamed
      #   raise Browserctl::Error, "state expired", code: "STATE_EXPIRED"
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
      #
      # The cop was tightened in v0.14 WS-1 PR 5 to remove the previous
      # "canonical SCREAMING_SNAKE string literals are also fine" escape
      # hatch — every `code:` must now be a constant reference so renames in
      # `Codes` propagate through the codebase via the constant, not via a
      # stale whitelist baked into this cop.
      class TypedError < RuboCop::Cop::Base
        MSG = "Browserctl raise: `code:` must reference Browserctl::Error::Codes::* — " \
              "got string literal %<value>p. See lib/browserctl/error/codes.rb."

        # Matches `raise Browserctl::Foo, ..., code: <value>` and yields the
        # `code:` value node.
        def_node_matcher :browserctl_raise_with_code, <<~PATTERN
          (send nil? :raise
            (const (const nil? :Browserctl) _)
            ...
            (hash <(pair (sym :code) $_) ...>))
        PATTERN

        # Matches `raise Browserctl::Foo.new(..., code: <value>, ...)` and
        # yields the `code:` value node. The base error initializer is
        # routinely called via `.new` (see `Browserctl::Error#initialize`),
        # so the cop needs to inspect both shapes.
        def_node_matcher :browserctl_raise_new_with_code, <<~PATTERN
          (send nil? :raise
            (send (const (const nil? :Browserctl) _) :new
              ...
              (hash <(pair (sym :code) $_) ...>)))
        PATTERN

        def on_send(node)
          return unless node.method?(:raise)

          [
            browserctl_raise_with_code(node),
            browserctl_raise_new_with_code(node)
          ].compact.each do |code_value|
            next unless code_value.str_type?

            add_offense(code_value, message: format(MSG, value: code_value.value))
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require "timeout"
require_relative "errors"
require_relative "secret_resolvers"

module Browserctl
  # Shared base for {Flow} and {WorkflowDefinition}. Holds the duplicated
  # DSL surface (`desc`, `param`, `step`) and the shared execution helpers
  # for resolving params and running step blocks with retry + timeout.
  #
  # Subclasses provide:
  # - their own `call`/`run` entry point and context object;
  # - {#callable_kind} so cross-type composition can be rejected at
  #   definition time (e.g. a flow trying to `compose` a workflow);
  # - {#step_failure_message} for the typed error wording.
  #
  # The persistence DSL (`store`/`fetch`/`save_state`/`load_state`) is
  # mixed into `WorkflowContext` via {ContextualPersistence} and is
  # deliberately absent from `FlowContext` — flows return state, workflows
  # share state.
  class CallableDefinition
    ParamDef = Data.define(:name, :required, :secret, :default, :secret_ref)
    StepDef  = Data.define(:label, :block, :retry_count, :timeout)

    attr_reader :name, :description, :param_defs, :steps

    def initialize(name)
      @name        = name.to_s
      @description = nil
      @param_defs  = {}
      @steps       = []
    end

    def desc(text)
      @description = text.to_s
    end

    def param(name, required: false, secret: false, default: nil, secret_ref: nil)
      secret = true if secret_ref
      @param_defs[name] = ParamDef.new(
        name: name,
        required: required,
        secret: secret,
        default: default,
        secret_ref: secret_ref
      )
    end

    def step(label, retry_count: 0, timeout: nil, &block)
      unless block
        raise Browserctl::Error.new(
          "#{callable_kind} step '#{label}' requires a block",
          code: Browserctl::Error::Codes::INVALID_DSL_USAGE,
          context: { dsl: callable_kind, action: :step, label: label }
        )
      end

      @steps << StepDef.new(label: label, block: block, retry_count: retry_count, timeout: timeout)
    end

    # Subclasses override these to specialise the base behaviour.

    # @return [Symbol] :flow or :workflow — used for cross-type composition checks.
    def callable_kind
      raise NotImplementedError
    end

    private

    def resolve_params(provided)
      @param_defs.each_with_object({}) do |(name, defn), out|
        val = if defn.secret_ref
                SecretResolverRegistry.resolve(defn.secret_ref)
              elsif provided.key?(name)
                provided[name]
              else
                defn.default
              end

        raise missing_param_error(name) if defn.required && val.nil?

        out[name] = val
      end
    end

    # Override for typed error wording.
    def missing_param_error(_name)
      raise NotImplementedError
    end

    # Runs a step block with retry + timeout. Yields the recoverable error
    # to the caller (via the returned exception in `:error`) so subclasses
    # can decide how to surface a failure (raise vs StepResult).
    def execute_step_block(ctx, defn)
      if defn.timeout
        ::Timeout.timeout(defn.timeout) { ctx.instance_exec(&defn.block) }
      else
        ctx.instance_exec(&defn.block)
      end
    rescue ::Timeout::Error
      raise step_timeout_error(defn)
    end

    def with_retries(defn)
      last_error = nil
      (defn.retry_count + 1).times do
        return yield
      rescue StandardError => e
        last_error = e
      end
      [:error, last_error]
    end

    # Subclasses override to raise their typed timeout error.
    def step_timeout_error(_defn)
      raise NotImplementedError
    end
  end
end

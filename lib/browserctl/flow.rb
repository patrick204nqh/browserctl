# frozen_string_literal: true

require_relative "callable_definition"
require_relative "errors"

module Browserctl
  FlowConditionDef = Struct.new(:kind, :label, :block, keyword_init: true)

  # Back-compat aliases — flow_wrapper specs reference these directly.
  FlowParamDef = CallableDefinition::ParamDef
  FlowStepDef  = CallableDefinition::StepDef

  class FlowContext
    attr_reader :page, :client, :params

    def initialize(page:, params:, client: nil)
      @page   = page
      @client = client
      @params = params
    end

    def method_missing(name, *args)
      return @params[name] if args.empty? && @params.key?(name)

      super
    end

    def respond_to_missing?(name, include_private = false)
      @params.key?(name) || super
    end
  end

  class Flow < CallableDefinition
    SEMVER_RE = /\A\d+\.\d+\.\d+\z/

    attr_reader :version_string,
                :preconditions,
                :postconditions,
                :produces_state_block,
                :min_browserctl_version

    def initialize(name)
      super
      @version_string         = "0.0.0"
      @preconditions          = []
      @postconditions         = []
      @produces_state_block   = nil
      @min_browserctl_version = nil
    end

    def callable_kind
      :flow
    end

    def version(value)
      validate_semver!(value, label: "version")
      @version_string = value.to_s
    end

    def requires_browserctl(value)
      validate_semver!(value, label: "requires_browserctl")
      @min_browserctl_version = value.to_s
    end

    def precondition(label = "precondition", &block)
      unless block
        raise Browserctl::Error.new(
          "precondition '#{label}' requires a block",
          code: Browserctl::Error::Codes::INVALID_DSL_USAGE,
          context: { dsl: :flow, action: :precondition, label: label }
        )
      end

      @preconditions << FlowConditionDef.new(kind: :precondition, label: label, block: block)
    end

    def postcondition(label = "postcondition", &block)
      unless block
        raise Browserctl::Error.new(
          "postcondition '#{label}' requires a block",
          code: Browserctl::Error::Codes::INVALID_DSL_USAGE,
          context: { dsl: :flow, action: :postcondition, label: label }
        )
      end

      @postconditions << FlowConditionDef.new(kind: :postcondition, label: label, block: block)
    end

    def produces_state(&block)
      unless block
        raise Browserctl::Error.new(
          "produces_state requires a block",
          code: Browserctl::Error::Codes::INVALID_DSL_USAGE,
          context: { dsl: :flow, action: :produces_state }
        )
      end

      @produces_state_block = block
    end

    # Definition-time guard against cross-type composition. A flow may only
    # compose other flows; pulling steps from a workflow would smuggle
    # `store`/`fetch` into a flow context that has no daemon-backed
    # persistence.
    def compose(target_name)
      name = target_name.to_s
      if Browserctl.respond_to?(:lookup_workflow) && Browserctl.lookup_workflow(name)
        raise Browserctl::Error.new(
          "flow '#{@name}' cannot compose workflow '#{name}': flows return state, " \
          "workflows share state — composition across kinds is not supported",
          code: Browserctl::Error::Codes::INVALID_DSL_USAGE,
          context: { dsl: :flow, action: :compose, source: @name, target: name, reason: :cross_kind }
        )
      end

      source = Browserctl.lookup_flow(name)
      unless source
        raise Browserctl::Error.new(
          "flow '#{name}' not found for composition",
          code: Browserctl::Error::Codes::INVALID_DSL_USAGE,
          context: { dsl: :flow, action: :compose, source: @name, target: name, reason: :not_found }
        )
      end

      @steps.concat(source.steps)
    end

    def run(page: nil, client: nil, **params)
      ctx = FlowContext.new(page: page, client: client, params: resolve_params(params))

      run_conditions(ctx, @preconditions, error_class: FlowPreconditionError)
      run_steps(ctx)
      run_conditions(ctx, @postconditions, error_class: FlowPostconditionError)

      produce_state(ctx)
    end

    private

    def validate_semver!(value, label:)
      return if value.to_s.match?(SEMVER_RE)

      raise Browserctl::Error.new(
        "#{label} must be MAJOR.MINOR.PATCH (got #{value.inspect})",
        code: Browserctl::Error::Codes::INVALID_DSL_USAGE,
        context: { dsl: :flow, action: :validate_semver, label: label, value: value.to_s }
      )
    end

    def missing_param_error(name)
      FlowParamError.new("flow '#{@name}' requires param '#{name}'")
    end

    def step_timeout_error(defn)
      FlowStepError.new("flow '#{@name}' step '#{defn.label}' timed out after #{defn.timeout}s")
    end

    def run_conditions(ctx, conditions, error_class:)
      conditions.each do |cond|
        result = ctx.instance_exec(&cond.block)
        next if result

        raise error_class,
              "flow '#{@name}' #{cond.kind} '#{cond.label}' returned #{result.inspect}"
      rescue FlowError
        raise
      rescue StandardError => e
        raise error_class,
              "flow '#{@name}' #{cond.kind} '#{cond.label}' raised: #{e.message}"
      end
    end

    def run_steps(ctx)
      @steps.each { |defn| run_step(ctx, defn) }
    end

    def run_step(ctx, defn)
      last_error = nil
      (defn.retry_count + 1).times do
        execute_step_block(ctx, defn)
        return
      rescue StandardError => e
        last_error = e
      end
      raise FlowStepError,
            "flow '#{@name}' step '#{defn.label}' failed: #{last_error.message}"
    end

    def produce_state(ctx)
      return nil unless @produces_state_block

      ctx.instance_exec(&@produces_state_block)
    end
  end

  @flow_registry_mutex = Mutex.new
  @flow_registry       = {}

  def self.flow(name, &block)
    unless block
      raise Browserctl::Error.new(
        "Browserctl.flow requires a block",
        code: Browserctl::Error::Codes::INVALID_DSL_USAGE,
        context: { dsl: :flow, action: :define, name: name.to_s }
      )
    end

    flow = Flow.new(name).tap { |f| f.instance_exec(&block) }
    register_flow(flow)
    flow
  end

  def self.register_flow(flow)
    @flow_registry_mutex.synchronize { @flow_registry[flow.name] = flow }
  end

  def self.lookup_flow(name)
    @flow_registry_mutex.synchronize { @flow_registry[name.to_s] }
  end

  def self.flow_registry_snapshot
    @flow_registry_mutex.synchronize { @flow_registry.dup }
  end

  def self.flow_registry_reset!
    @flow_registry_mutex.synchronize { @flow_registry.clear }
  end
end

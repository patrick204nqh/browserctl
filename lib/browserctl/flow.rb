# frozen_string_literal: true

require "timeout"
require_relative "errors"
require_relative "secret_resolvers"

module Browserctl
  FlowParamDef    = Struct.new(:name, :required, :secret, :default, :secret_ref, keyword_init: true)
  FlowStepDef     = Struct.new(:label, :block, :retry_count, :timeout, keyword_init: true)
  FlowConditionDef = Struct.new(:kind, :label, :block, keyword_init: true)

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

  class Flow
    SEMVER_RE = /\A\d+\.\d+\.\d+\z/

    attr_reader :name,
                :version_string,
                :description,
                :param_defs,
                :steps,
                :preconditions,
                :postconditions,
                :produces_state_block,
                :min_browserctl_version

    def initialize(name)
      @name                   = name.to_s
      @version_string         = "0.0.0"
      @description            = nil
      @param_defs             = {}
      @steps                  = []
      @preconditions          = []
      @postconditions         = []
      @produces_state_block   = nil
      @min_browserctl_version = nil
    end

    def version(value)
      validate_semver!(value, label: "version")
      @version_string = value.to_s
    end

    def requires_browserctl(value)
      validate_semver!(value, label: "requires_browserctl")
      @min_browserctl_version = value.to_s
    end

    def desc(text)
      @description = text.to_s
    end

    def param(name, required: false, secret: false, default: nil, secret_ref: nil)
      secret = true if secret_ref
      @param_defs[name] = FlowParamDef.new(
        name: name,
        required: required,
        secret: secret,
        default: default,
        secret_ref: secret_ref
      )
    end

    def step(label, retry_count: 0, timeout: nil, &block)
      raise ArgumentError, "flow step '#{label}' requires a block" unless block

      @steps << FlowStepDef.new(label: label, block: block, retry_count: retry_count, timeout: timeout)
    end

    def precondition(label = "precondition", &block)
      raise ArgumentError, "precondition '#{label}' requires a block" unless block

      @preconditions << FlowConditionDef.new(kind: :precondition, label: label, block: block)
    end

    def postcondition(label = "postcondition", &block)
      raise ArgumentError, "postcondition '#{label}' requires a block" unless block

      @postconditions << FlowConditionDef.new(kind: :postcondition, label: label, block: block)
    end

    def produces_state(&block)
      raise ArgumentError, "produces_state requires a block" unless block

      @produces_state_block = block
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

      raise ArgumentError, "#{label} must be MAJOR.MINOR.PATCH (got #{value.inspect})"
    end

    def resolve_params(provided)
      @param_defs.each_with_object({}) do |(name, defn), out|
        val = if defn.secret_ref
                SecretResolverRegistry.resolve(defn.secret_ref)
              elsif provided.key?(name)
                provided[name]
              else
                defn.default
              end

        raise FlowParamError, "flow '#{@name}' requires param '#{name}'" if defn.required && val.nil?

        out[name] = val
      end
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

    def execute_step_block(ctx, defn)
      if defn.timeout
        ::Timeout.timeout(defn.timeout) { ctx.instance_exec(&defn.block) }
      else
        ctx.instance_exec(&defn.block)
      end
    rescue ::Timeout::Error
      raise FlowStepError,
            "flow '#{@name}' step '#{defn.label}' timed out after #{defn.timeout}s"
    end

    def produce_state(ctx)
      return nil unless @produces_state_block

      ctx.instance_exec(&@produces_state_block)
    end
  end

  @flow_registry_mutex = Mutex.new
  @flow_registry       = {}

  def self.flow(name, &block)
    raise ArgumentError, "Browserctl.flow requires a block" unless block

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

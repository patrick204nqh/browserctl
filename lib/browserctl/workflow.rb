# frozen_string_literal: true

require "timeout"
require_relative "client"

module Browserctl
  class WorkflowError < StandardError; end

  ParamDef = Struct.new(:name, :required, :secret, :default, keyword_init: true)
  StepResult = Struct.new(:name, :ok, :error, keyword_init: true)
  StepDef = Struct.new(:label, :block, :retry_count, :timeout, keyword_init: true)

  class WorkflowContext
    attr_reader :client

    def initialize(params, client)
      @params = params
      @client = client
    end

    def method_missing(name, *args)
      return @params[name] if @params.key?(name)

      super
    end

    def respond_to_missing?(name, include_private = false)
      @params.key?(name) || super
    end

    def page(name)
      PageProxy.new(name.to_s, @client)
    end

    def invoke(workflow_name, **override_params)
      name = workflow_name.to_s
      guard_circular!(name)
      track_invoke(name) { run_nested(workflow_name, **override_params) }
    end

    def assert(condition, msg = "assertion failed")
      raise WorkflowError, msg unless condition
    end

    private

    def invoke_stack
      @invoke_stack ||= []
    end

    def guard_circular!(name)
      return unless invoke_stack.include?(name)

      raise WorkflowError, "circular workflow invocation: #{(invoke_stack + [name]).join(' → ')}"
    end

    def track_invoke(name)
      invoke_stack << name
      yield
    ensure
      invoke_stack.pop
    end

    def run_nested(workflow_name, **override_params)
      Runner.new.run_workflow(workflow_name, **@params, **override_params)
    end
  end

  class PageProxy
    def initialize(name, client)
      @name   = name
      @client = client
    end

    def goto(url)        = unwrap @client.goto(@name, url)
    def fill(sel, val)   = unwrap @client.fill(@name, sel, val)
    def click(sel)       = unwrap @client.click(@name, sel)
    def snapshot(**) = unwrap @client.snapshot(@name, **)
    def screenshot(**) = unwrap @client.screenshot(@name, **)
    def wait_for(sel, timeout: 10) = unwrap @client.wait_for(@name, sel, timeout: timeout)
    def url              = @client.url(@name)[:url]
    def evaluate(expr)   = @client.evaluate(@name, expr)[:result]

    private

    def unwrap(res)
      raise WorkflowError, res[:error] if res[:error]

      res
    end
  end

  class WorkflowDefinition
    attr_reader :name, :description, :param_defs, :steps

    def initialize(name)
      @name = name
      @description = nil
      @param_defs  = {}
      @steps       = []
    end

    def desc(text)
      @description = text
    end

    def param(name, required: false, secret: false, default: nil)
      @param_defs[name] = ParamDef.new(name: name, required: required, secret: secret, default: default)
    end

    def step(label, retry_count: 0, timeout: nil, &block)
      @steps << StepDef.new(label: label, block: block, retry_count: retry_count, timeout: timeout)
    end

    def call(params, client)
      ctx = WorkflowContext.new(resolve_params(params), client)
      execute_steps(ctx)
    end

    private

    def execute_steps(ctx)
      @steps.map { |defn| run_step(ctx, defn) }.each do |r|
        raise WorkflowError, "step '#{r.name}' failed: #{r.error}" unless r.ok
      end
    end

    def run_step(ctx, defn)
      last_error = nil
      (defn.retry_count + 1).times do
        execute_block(ctx, defn)
        return StepResult.new(name: defn.label, ok: true)
      rescue WorkflowError, StandardError => e
        last_error = e
      end
      StepResult.new(name: defn.label, ok: false, error: last_error.message)
    end

    def execute_block(ctx, defn)
      if defn.timeout
        ::Timeout.timeout(defn.timeout) { ctx.instance_exec(&defn.block) }
      else
        ctx.instance_exec(&defn.block)
      end
    rescue ::Timeout::Error
      raise WorkflowError, "step '#{defn.label}' timed out after #{defn.timeout}s"
    end

    def resolve_params(provided)
      @param_defs.each_with_object({}) do |(name, defn), out|
        val = provided[name] || defn.default
        raise WorkflowError, "required param '#{name}' missing" if defn.required && val.nil?

        out[name] = val
      end
    end
  end

  REGISTRY = {} # rubocop:disable Style/MutableConstant

  def self.workflow(name, &)
    defn = WorkflowDefinition.new(name.to_s)
    defn.instance_exec(&)
    REGISTRY[name.to_s] = defn
  end
end

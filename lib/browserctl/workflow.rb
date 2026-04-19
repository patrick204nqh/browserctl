require_relative "client"

module Browserctl
  class WorkflowError < StandardError; end

  ParamDef = Struct.new(:name, :required, :secret, :default, keyword_init: true)
  StepResult = Struct.new(:name, :ok, :error, keyword_init: true)

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
      Runner.new.run_workflow(workflow_name, **@params.merge(override_params))
    end

    def assert(condition, msg = "assertion failed")
      raise WorkflowError, msg unless condition
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
    def snapshot(**opts) = unwrap @client.snapshot(@name, **opts)
    def screenshot(**opts) = unwrap @client.screenshot(@name, **opts)
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
      @name       = name
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

    def step(label, &block)
      @steps << [label, block]
    end

    def call(params, client)
      resolved = resolve_params(params)
      ctx      = WorkflowContext.new(resolved, client)
      results  = []

      @steps.each do |label, block|
        begin
          ctx.instance_exec(&block)
          results << StepResult.new(name: label, ok: true)
        rescue WorkflowError, Ferrum::Error => e
          results << StepResult.new(name: label, ok: false, error: e.message)
          raise WorkflowError, "step '#{label}' failed: #{e.message}"
        end
      end

      results
    end

    private

    def resolve_params(provided)
      out = {}
      @param_defs.each do |name, defn|
        val = provided[name] || defn.default
        raise WorkflowError, "required param '#{name}' missing" if defn.required && val.nil?
        out[name] = val
      end
      out
    end
  end

  REGISTRY = {}

  def self.workflow(name, &block)
    defn = WorkflowDefinition.new(name.to_s)
    defn.instance_exec(&block)
    REGISTRY[name.to_s] = defn
  end
end

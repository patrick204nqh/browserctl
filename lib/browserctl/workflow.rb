# frozen_string_literal: true

require "timeout"
require_relative "client"
require_relative "errors"
require_relative "secret_resolvers"

module Browserctl
  ParamDef = Struct.new(:name, :required, :secret, :default, :secret_ref, keyword_init: true)
  StepResult = Struct.new(:name, :ok, :error, keyword_init: true)
  StepDef = Struct.new(:label, :block, :retry_count, :timeout, keyword_init: true)

  class WorkflowContext
    attr_reader :client

    def initialize(params, client)
      @params = params
      @client = client
    end

    def store(key, value)
      res = @client.store(key.to_s, value)
      raise WorkflowError, res[:error] if res[:error]

      value
    end

    def fetch(key)
      res = @client.fetch(key.to_s)
      raise WorkflowError, res[:error] if res[:error]

      res[:value]
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

    def open_page(page_name, url: nil)
      res = @client.page_open(page_name.to_s, url: url)
      raise WorkflowError, res[:error] if res[:error]

      res
    end

    def close_page(page_name)
      res = @client.page_close(page_name.to_s)
      raise WorkflowError, res[:error] if res[:error]

      res
    end

    def save_session(session_name)
      res = @client.session_save(session_name)
      raise WorkflowError, res[:error] if res[:error]

      res
    end

    def load_session(session_name, fallback: nil)
      res = @client.session_load(session_name)
      return res unless res[:error]

      raise WorkflowError, res[:error] unless fallback

      invoke(fallback.to_s)
      res2 = @client.session_load(session_name)
      raise WorkflowError, "session '#{session_name}' still unavailable after running fallback '#{fallback}'" if res2[:error]

      res2
    end

    def list_sessions
      @client.session_list[:sessions]
    end

    def ask(prompt)
      $stderr.print("[browserctl] #{prompt} ")
      $stdin.gets.chomp
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

    def navigate(url)             = unwrap @client.navigate(@name, url)
    def fill(sel, val)            = unwrap @client.fill(@name, sel, val)
    def click(sel)                = unwrap @client.click(@name, sel)
    def snapshot(**)              = unwrap @client.snapshot(@name, **)
    def screenshot(**)            = unwrap @client.screenshot(@name, **)
    def wait(sel, timeout: 30)    = unwrap @client.wait(@name, sel, timeout: timeout)
    def delete_cookies             = unwrap @client.delete_cookies(@name)
    def devtools                   = @client.devtools(@name)[:devtools_url]
    def url                        = @client.url(@name)[:url]
    def evaluate(expr)             = @client.evaluate(@name, expr)[:result]

    def storage_get(key, store: "local")
      @client.storage_get(@name, key, store: store)[:value]
    end

    def storage_set(key, value, store: "local")
      unwrap @client.storage_set(@name, key, value, store: store)
    end

    def press(key)               = unwrap @client.press(@name, key)
    def hover(selector)          = unwrap @client.hover(@name, selector)
    def upload(selector, path)   = unwrap @client.upload(@name, selector, path)
    def select(selector, value)  = unwrap @client.select(@name, selector, value)
    def dialog_accept(text: nil) = unwrap @client.dialog_accept(@name, text: text)
    def dialog_dismiss           = unwrap @client.dialog_dismiss(@name)

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

    def param(name, required: false, secret: false, default: nil, secret_ref: nil)
      secret = true if secret_ref
      @param_defs[name] = ParamDef.new(name: name, required: required, secret: secret, default: default, secret_ref: secret_ref)
    end

    def step(label, retry_count: 0, timeout: nil, &block)
      @steps << StepDef.new(label: label, block: block, retry_count: retry_count, timeout: timeout)
    end

    def compose(workflow_name)
      source = Browserctl.lookup_workflow(workflow_name.to_s)
      raise WorkflowError, "workflow '#{workflow_name}' not found for composition" unless source

      @steps.concat(source.steps)
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
        val = if defn.secret_ref
                SecretResolverRegistry.resolve(defn.secret_ref)
              else
                provided[name] || defn.default
              end
        raise WorkflowError, "required param '#{name}' missing" if defn.required && val.nil?

        out[name] = val
      end
    end
  end

  @registry_mutex = Mutex.new
  @registry = {}

  def self.workflow(name, &)
    defn = WorkflowDefinition.new(name.to_s)
    defn.instance_exec(&)
    @registry_mutex.synchronize { @registry[name.to_s] = defn }
  end

  def self.lookup_workflow(name)
    @registry_mutex.synchronize { @registry[name.to_s] }
  end

  def self.registry_snapshot
    @registry_mutex.synchronize { @registry.dup }
  end
end

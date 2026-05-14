# frozen_string_literal: true

require_relative "callable_definition"
require_relative "client"
require_relative "contextual_persistence"
require_relative "errors"
require_relative "flow_registry"
require_relative "replay/context"
require_relative "replay/fingerprint_matcher"
require_relative "replay/snapshot_diff"
require_relative "workflow/page_proxy"

module Browserctl
  # Workflow-file format version. Workflows are Ruby files; the schema gate
  # is a top-of-file comment header:
  #
  #   # format_version: 1
  #
  # Unlike bundles and recordings, an unsupported or missing version on a
  # workflow file is a *warning*, not a hard failure. Workflows are
  # human-authored Ruby — the loader prefers to surface drift via stderr
  # and let the file run, rather than block execution. See
  # docs/reference/format-versions.md.
  WORKFLOW_FORMAT_VERSION = 1
  SUPPORTED_WORKFLOW_FORMAT_VERSIONS = [WORKFLOW_FORMAT_VERSION].freeze

  # Matches a leading-line comment of the form `# format_version: <int>`.
  # Tolerates leading whitespace inside the comment body and ignores the
  # `# frozen_string_literal: true` magic comment that conventionally
  # precedes it.
  WORKFLOW_FORMAT_VERSION_HEADER = /^\s*#\s*format_version:\s*(\d+)\s*$/

  # Parses the `# format_version: N` header from a workflow file's source.
  # Scans only the contiguous leading comment block (and blank lines) so
  # the header cannot be smuggled in mid-file. Returns the integer if
  # present, or nil if the file has no version header.
  def self.parse_workflow_format_version(source)
    source.each_line do |line|
      stripped = line.strip
      next if stripped.empty?
      break unless stripped.start_with?("#")

      if (m = line.match(WORKFLOW_FORMAT_VERSION_HEADER))
        return Integer(m[1])
      end
    end
    nil
  end

  # Reads a workflow file and warns to stderr when the `format_version:`
  # header is missing or declares an unsupported version. Always returns
  # the parsed integer (or nil) — never raises. Callers should still
  # `load` the file regardless.
  def self.verify_workflow_format_version!(path)
    source = File.read(path)
    version = parse_workflow_format_version(source)

    if version.nil?
      warn "[browserctl] workflow #{path} is missing a `# format_version: N` header " \
           "(expected #{WORKFLOW_FORMAT_VERSION}); proceeding anyway"
    elsif !SUPPORTED_WORKFLOW_FORMAT_VERSIONS.include?(version)
      warn "[browserctl] workflow #{path} format_version=#{version} is not supported " \
           "(expected #{WORKFLOW_FORMAT_VERSION}); proceeding anyway"
    end

    version
  end

  # Back-compat aliases — exposed in the public surface (flow_wrapper specs,
  # workflow specs reference these directly).
  ParamDef = CallableDefinition::ParamDef
  StepDef  = CallableDefinition::StepDef
  StepResult = Data.define(:name, :ok, :error)

  class WorkflowContext
    include ContextualPersistence

    attr_reader :client, :replay_context, :params

    def initialize(params, client, replay_context: nil)
      @params = params
      @client = client
      @replay_context = replay_context
    end

    def method_missing(name, *args)
      return @params[name] if @params.key?(name)

      super
    end

    def respond_to_missing?(name, include_private = false)
      @params.key?(name) || super
    end

    def page(name)
      PageProxy.new(name.to_s, @client, replay_context: @replay_context)
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

    def ask(prompt)
      $stderr.print("[browserctl] #{prompt} ")
      $stdin.gets.chomp
    end

    def invoke(target_name, page: nil, **override_params)
      name = target_name.to_s
      guard_circular!(name)

      flow = lookup_flow_target(name)
      if flow
        track_invoke(name) { run_invoked_flow(flow, page_name: page, **override_params) }
      else
        track_invoke(name) { run_nested(target_name, **override_params) }
      end
    end

    def assert(condition, msg = "assertion failed")
      raise WorkflowError, msg unless condition
    end

    # Snapshots the named page and compares its digest against `expected_digest`.
    # Under `workflow run --check` (a replay context is attached), a mismatch is
    # recorded as a drift event with reason "post-snapshot mismatch" and the
    # step still passes. Outside --check, mismatch raises WorkflowError so the
    # workflow fails fast.
    def assert_snapshot_stable(page_name, expected_digest:)
      res = @client.snapshot(page_name.to_s, format: "elements")
      snapshot = res[:snapshot]
      actual = Replay::SnapshotDiff.digest(snapshot)
      return if actual == expected_digest

      msg = "post-snapshot mismatch on :#{page_name} — expected #{expected_digest}, got #{actual}"
      raise WorkflowError, msg unless @replay_context

      @replay_context.record(command: :assert_snapshot_stable, selector: page_name.to_s,
                             matched_ref: nil, score: nil, reason: "post-snapshot mismatch")
      warn "[browserctl replay] #{msg}"
    end

    def compose(*)
      raise WorkflowError,
            "`compose` must be called at the workflow definition level, not inside a step block. " \
            "Did you mean `invoke`?"
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

    def lookup_flow_target(name)
      Browserctl.lookup_flow(name) || begin
        FlowRegistry.resolve(name)
      rescue ArgumentError
        nil
      end
    end

    def run_invoked_flow(flow, page_name:, **params)
      proxy = page_name ? page(page_name) : nil
      flow.run(page: proxy, client: @client, **params)
    end
  end

  class WorkflowDefinition < CallableDefinition
    def callable_kind
      :workflow
    end

    # Definition-time guard: composing a flow into a workflow would copy
    # flow steps that may close over `page` (a flow-only DSL) into a
    # context that doesn't expose it. Cross-kind composition is rejected
    # here rather than failing later inside an `instance_exec`.
    def compose(workflow_name)
      name = workflow_name.to_s
      if Browserctl.lookup_flow(name)
        raise Browserctl::Error.new(
          "workflow '#{@name}' cannot compose flow '#{name}': flows return state, " \
          "workflows share state — composition across kinds is not supported",
          code: Browserctl::Error::Codes::INVALID_DSL_USAGE,
          context: { workflow: @name, flow: name, kind: :cross_kind_compose }
        )
      end

      source = Browserctl.lookup_workflow(name)
      raise WorkflowError, "workflow '#{workflow_name}' not found for composition" unless source

      @steps.concat(source.steps)
    end

    def call(params, client, replay_context: nil)
      ctx = WorkflowContext.new(resolve_params(params), client, replay_context: replay_context)
      execute_steps(ctx)
    end

    private

    def missing_param_error(name)
      WorkflowError.new("required param '#{name}' missing")
    end

    def step_timeout_error(defn)
      WorkflowError.new("step '#{defn.label}' timed out after #{defn.timeout}s")
    end

    def execute_steps(ctx)
      @steps.map { |defn| run_step(ctx, defn) }.each do |r|
        raise WorkflowError, "step '#{r.name}' failed: #{r.error}" unless r.ok
      end
    end

    def run_step(ctx, defn)
      last_error = nil
      (defn.retry_count + 1).times do
        execute_step_block(ctx, defn)
        return StepResult.new(name: defn.label, ok: true, error: nil)
      rescue StandardError => e
        last_error = e
      end
      StepResult.new(name: defn.label, ok: false, error: last_error.message)
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

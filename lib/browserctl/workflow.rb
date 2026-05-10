# frozen_string_literal: true

require "timeout"
require_relative "client"
require_relative "errors"
require_relative "flow_registry"
require_relative "replay/context"
require_relative "replay/fingerprint_matcher"
require_relative "replay/snapshot_diff"
require_relative "secret_resolvers"

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

  ParamDef = Struct.new(:name, :required, :secret, :default, :secret_ref, keyword_init: true)
  StepResult = Struct.new(:name, :ok, :error, keyword_init: true)
  StepDef = Struct.new(:label, :block, :retry_count, :timeout, keyword_init: true)

  class WorkflowContext
    attr_reader :client, :replay_context, :params

    def initialize(params, client, replay_context: nil)
      @params = params
      @client = client
      @replay_context = replay_context
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

    # Persists the daemon's current cookies + storage as a .bctl bundle.
    # Optional flow binding lets `load_state` auto-rotate when the bundle
    # is detected as needing authentication.
    def save_state(name, flow: nil, origins: nil, encrypt: false)
      passphrase = encrypt ? ENV.fetch("BROWSERCTL_STATE_PASSPHRASE", nil) : nil
      res = @client.state_save(name.to_s,
                               flow: flow&.to_s, origins: origins, passphrase: passphrase)
      raise WorkflowError, res[:error] if res[:error]

      res
    end

    # Restores a .bctl bundle. When the daemon detects AUTH_REQUIRED before
    # applying (e.g. expired cookies in the payload), this rotates the bound
    # flow and retries — no caller code change required.
    #
    # @param on_auth_required [Proc, nil] override the auto-rotate path. The
    #   block runs in the workflow context, in lieu of invoking the manifest's
    #   bound flow. Use this when the recovery procedure is bespoke.
    def load_state(name, on_auth_required: nil)
      res = @client.state_load(name.to_s)
      return res unless auth_required_response?(res)

      recover_auth_required_state(name.to_s, res, on_auth_required)
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

    def auth_required_response?(res)
      (res[:code] || res["code"]) == "AUTH_REQUIRED"
    end

    def recover_auth_required_state(name, initial_res, on_auth_required)
      if on_auth_required
        on_auth_required.call
      else
        flow_name = initial_res[:suggested_flow] || initial_res["suggested_flow"]
        unless flow_name && !flow_name.to_s.empty?
          raise WorkflowError,
                "state '#{name}' needs auth but bundle has no bound flow — " \
                "save with `save_state('#{name}', flow: :NAME)` or pass on_auth_required:"
        end

        # Match the daemon's `state load` preflight: it auth-checks the first
        # open page (insertion order). Passing that same name to the flow
        # gives stdlib flows a `page` proxy to drive (oauth_github reads
        # `page.url`, totp_2fa calls `page.fill`, etc.). Falls back to no
        # page only when nothing is open — `state_save` would have errored
        # earlier in that case, so this is a defence-in-depth nil.
        invoke(flow_name, page: first_open_page)
      end

      after_save = @client.state_save(name)
      raise WorkflowError, after_save[:error] if after_save[:error]

      retry_res = @client.state_load(name, skip_auth_check: true)
      raise WorkflowError, retry_res[:error] if retry_res[:error]

      retry_res.merge(rotated: true)
    end

    def first_open_page
      res = @client.page_list
      pages = res[:pages] || res["pages"] || []
      pages.first
    end

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

  class PageProxy
    attr_accessor :replay_context

    def initialize(name, client, replay_context: nil, matcher: nil)
      @name           = name
      @client         = client
      @replay_context = replay_context
      @matcher        = matcher || Replay::FingerprintMatcher.new
    end

    def navigate(url) = unwrap @client.navigate(@name, url)

    def fill(selector = nil, value = nil, ref: nil)
      with_selector_fallback(:fill, selector, ref) do |sel, r|
        @client.fill(@name, sel, value, ref: r)
      end
    end

    def click(selector = nil, ref: nil)
      with_selector_fallback(:click, selector, ref) do |sel, r|
        @client.click(@name, sel, ref: r)
      end
    end

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

    def press(key) = unwrap @client.press(@name, key)

    def hover(selector = nil, ref: nil)
      with_selector_fallback(:hover, selector, ref) do |sel, r|
        @client.hover(@name, sel, ref: r)
      end
    end

    def upload(selector = nil, path = nil, ref: nil)
      with_selector_fallback(:upload, selector, ref) do |sel, r|
        @client.upload(@name, sel, path, ref: r)
      end
    end

    def select(selector = nil, value = nil, ref: nil)
      with_selector_fallback(:select, selector, ref) do |sel, r|
        @client.select(@name, sel, value, ref: r)
      end
    end

    def dialog_accept(text: nil) = unwrap @client.dialog_accept(@name, text: text)
    def dialog_dismiss           = unwrap @client.dialog_dismiss(@name)

    private

    # Issues the wrapped command. If the daemon returns selector_not_found
    # and a replay context has a fingerprint for this selector, takes a
    # fresh snapshot, asks the matcher for a candidate, and retries by ref.
    def with_selector_fallback(cmd, selector, ref)
      res = yield(selector, ref)
      return unwrap(res) if !selector_not_found?(res) || ref || !@replay_context || !selector

      fp = @replay_context.fingerprint_for(selector)
      return unwrap(res) unless fp

      match = @matcher.best(fp, snapshot_entries)
      unless match
        @replay_context.record(command: cmd, selector: selector, reason: "no candidate above threshold")
        return unwrap(res)
      end

      log_rematch(cmd, selector, match)
      @replay_context.record(command: cmd, selector: selector,
                             matched_ref: match.candidate[:ref], score: match.score, reason: "rematch")
      unwrap(yield(nil, match.candidate[:ref]))
    end

    def snapshot_entries
      res = @client.snapshot(@name, format: "elements")
      Array(res[:snapshot])
    end

    def selector_not_found?(res)
      res.is_a?(Hash) && res[:code] == Browserctl::Error::Codes::SELECTOR_NOT_FOUND
    end

    def log_rematch(cmd, selector, match)
      warn "[browserctl replay] #{cmd} selector #{selector.inspect} not found — " \
           "rematched to ref=#{match.candidate[:ref]} (score=#{format('%.2f', match.score)})"
    end

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
      @param_defs[name] =
        ParamDef.new(name: name, required: required, secret: secret, default: default, secret_ref: secret_ref)
    end

    def step(label, retry_count: 0, timeout: nil, &block)
      @steps << StepDef.new(label: label, block: block, retry_count: retry_count, timeout: timeout)
    end

    def compose(workflow_name)
      source = Browserctl.lookup_workflow(workflow_name.to_s)
      raise WorkflowError, "workflow '#{workflow_name}' not found for composition" unless source

      @steps.concat(source.steps)
    end

    def call(params, client, replay_context: nil)
      ctx = WorkflowContext.new(resolve_params(params), client, replay_context: replay_context)
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
      rescue StandardError => e
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

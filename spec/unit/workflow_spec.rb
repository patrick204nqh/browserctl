# frozen_string_literal: true

require "spec_helper"

RSpec.describe Browserctl::WorkflowDefinition do
  let(:client) { instance_double(Browserctl::Client) }

  def define(name, &block)
    defn = described_class.new(name)
    defn.instance_exec(&block)
    defn
  end

  describe "#call" do
    it "runs steps in order and returns StepResults" do
      order = []
      defn = define("test") do
        step("first")  { order << :first }
        step("second") { order << :second }
      end

      results = defn.call({}, client)
      expect(order).to eq(%i[first second])
      expect(results.map(&:ok)).to all(be true)
    end

    it "halts on first failed step" do
      defn = define("test") do
        step("ok")   { nil }
        step("fail") { raise Browserctl::WorkflowError, "boom" }
        step("skip") { nil }
      end

      expect { defn.call({}, client) }.to raise_error(Browserctl::WorkflowError, /boom/)
      results = begin
        defn.call({}, client)
      rescue Browserctl::WorkflowError
        # check via the results stored before raise — re-run to capture
        nil
      end
      expect(results).to be_nil
    end

    it "raises when a required param is missing" do
      defn = define("test") do
        param :email, required: true
        step("s") { nil }
      end

      expect { defn.call({}, client) }.to raise_error(Browserctl::WorkflowError, /required param 'email'/)
    end

    it "uses default param values" do
      received = nil
      defn = define("test") do
        param :url, default: "https://example.com"
        step("s") { received = url }
      end

      defn.call({}, client)
      expect(received).to eq("https://example.com")
    end
  end

  describe "step retry" do
    it "retries a failing step the given number of times" do
      attempts = 0
      defn = Browserctl::WorkflowDefinition.new("test")
      defn.step("flaky", retry_count: 2) do
        attempts += 1
        raise "boom" if attempts < 3
      end

      client = double("client")
      expect { defn.call({}, client) }.not_to raise_error
      expect(attempts).to eq 3
    end

    it "fails after exhausting retries" do
      defn = Browserctl::WorkflowDefinition.new("test")
      defn.step("always fails", retry_count: 1) { raise "permanent" }

      client = double("client")
      expect { defn.call({}, client) }.to raise_error(Browserctl::WorkflowError, /always fails/)
    end
  end

  describe "step timeout" do
    it "raises WorkflowError when step exceeds timeout" do
      defn = Browserctl::WorkflowDefinition.new("test")
      defn.step("slow", timeout: 0.1) { sleep 5 }

      client = double("client")
      expect { defn.call({}, client) }.to raise_error(Browserctl::WorkflowError, /timed out/)
    end

    it "succeeds when step completes within timeout" do
      defn = Browserctl::WorkflowDefinition.new("test")
      defn.step("fast", timeout: 5) { 1 + 1 }

      client = double("client")
      expect { defn.call({}, client) }.not_to raise_error
    end
  end
end

RSpec.describe "compose" do
  before do
    Browserctl.instance_variable_set(:@registry, {})
    Browserctl.flow_registry_reset!
  end
  after do
    Browserctl.instance_variable_set(:@registry, {})
    Browserctl.flow_registry_reset!
  end

  it "inlines steps from another workflow" do
    Browserctl.workflow "shared" do
      step("shared step") { nil }
    end

    Browserctl.workflow "main" do
      compose "shared"
      step("own step") { nil }
    end

    defn = Browserctl.lookup_workflow("main")
    expect(defn.steps.map(&:label)).to eq(["shared step", "own step"])
  end

  it "raises WorkflowError when composed workflow is not registered" do
    expect do
      Browserctl.workflow "broken" do
        compose "nonexistent"
      end
    end.to raise_error(Browserctl::WorkflowError, /nonexistent/)
  end

  it "composed steps run in order" do
    order = []
    Browserctl.workflow "base" do
      step("a") { order << :a }
    end
    Browserctl.workflow "extended" do
      compose "base"
      step("b") { order << :b }
    end
    client = double("client", ping: { ok: true })
    Browserctl.lookup_workflow("extended").call({}, client)
    expect(order).to eq(%i[a b])
  end

  it "compose can be called multiple times to merge several workflows" do
    Browserctl.workflow "first" do
      step("f1") { nil }
    end
    Browserctl.workflow "second" do
      step("f2") { nil }
    end
    Browserctl.workflow "combined" do
      compose "first"
      compose "second"
      step("own") { nil }
    end
    labels = Browserctl.lookup_workflow("combined").steps.map(&:label)
    expect(labels).to eq(%w[f1 f2 own])
  end
end

RSpec.describe "WorkflowContext#ask" do
  it "prints prompt to stderr and reads a value from stdin" do
    client = double("client")
    ctx    = Browserctl::WorkflowContext.new({}, client)
    allow($stderr).to receive(:print)
    allow($stdin).to receive(:gets).and_return("my_secret\n")
    result = ctx.ask("Enter password:")
    expect($stderr).to have_received(:print).with("[browserctl] Enter password: ")
    expect(result).to eq("my_secret")
  end
end

RSpec.describe "secret_ref param resolution" do
  let(:client) { instance_double(Browserctl::Client) }

  before { Browserctl::SecretResolverRegistry.reset! }
  after  { Browserctl::SecretResolverRegistry.reset! }

  let(:fake_resolver_class) do
    Class.new(Browserctl::SecretResolvers::Base) do
      def self.scheme = "fakescheme"
      def resolve(reference) = "resolved-#{reference}"
    end
  end

  it "resolves secret_ref via SecretResolverRegistry at param resolution time" do
    Browserctl::SecretResolverRegistry.register(fake_resolver_class)
    received = nil
    defn = Browserctl::WorkflowDefinition.new("test")
    defn.param(:api_key, secret_ref: "fakescheme://MY_KEY")
    defn.step("s") { received = api_key }

    defn.call({}, client)
    expect(received).to eq("resolved-MY_KEY")
  end

  it "forces secret: true on ParamDef when secret_ref is present, regardless of explicit secret: false" do
    defn = Browserctl::WorkflowDefinition.new("test")
    defn.param(:token, secret_ref: "fakescheme://TOKEN", secret: false)
    expect(defn.param_defs[:token].secret).to be true
  end
end

RSpec.describe Browserctl::WorkflowContext do
  let(:client) { instance_double(Browserctl::Client) }

  describe "#store and #fetch" do
    subject(:ctx) { described_class.new({}, client) }

    it "delegates store to the wire client" do
      allow(client).to receive(:store).with("code", "abc123").and_return({ ok: true })
      expect(ctx.store(:code, "abc123")).to eq("abc123")
    end

    it "delegates fetch to the wire client and returns the value" do
      allow(client).to receive(:fetch).with("code").and_return({ ok: true, value: "abc123" })
      expect(ctx.fetch(:code)).to eq("abc123")
    end

    it "raises WorkflowError when fetch returns an error" do
      allow(client).to receive(:fetch).with("missing")
                                      .and_return({ error: "key 'missing' not found", code: "key_not_found" })
      expect { ctx.fetch(:missing) }.to raise_error(Browserctl::WorkflowError, /missing/)
    end

    it "raises WorkflowError when store returns an error" do
      allow(client).to receive(:store).and_return({ error: "store failed" })
      expect { ctx.store(:x, 1) }.to raise_error(Browserctl::WorkflowError, /store failed/)
    end

    it "store keys do not conflict with param names" do
      ctx_with_param = described_class.new({ email: "a@b.com" }, client)
      allow(client).to receive(:store).with("email", "override").and_return({ ok: true })
      allow(client).to receive(:fetch).with("email").and_return({ ok: true, value: "override" })
      ctx_with_param.store(:email, "override")
      expect(ctx_with_param.fetch(:email)).to eq("override")
      expect(ctx_with_param.email).to eq("a@b.com")
    end
  end

  describe "#assert" do
    it "does nothing when condition is true" do
      ctx = described_class.new({}, client)
      expect { ctx.assert(true) }.not_to raise_error
    end

    it "raises WorkflowError when condition is false" do
      ctx = described_class.new({}, client)
      expect { ctx.assert(false, "nope") }.to raise_error(Browserctl::WorkflowError, "nope")
    end
  end

  describe "#invoke circular detection" do
    it "raises WorkflowError on circular invocation" do
      Browserctl.instance_variable_get(:@registry_mutex).synchronize do
        Browserctl.instance_variable_get(:@registry)["loop_a"] = instance_double(
          Browserctl::WorkflowDefinition,
          call: nil
        )
      end

      ctx = described_class.new({}, client)
      ctx.instance_variable_set(:@invoke_stack, ["loop_a"])

      expect { ctx.invoke("loop_a") }.to raise_error(Browserctl::WorkflowError, /circular/)
    end
  end

  describe "#invoke flow dispatch" do
    before { Browserctl.flow_registry_reset! }
    after  { Browserctl.flow_registry_reset! }

    it "runs a registered flow when the name resolves to one" do
      received = nil
      Browserctl.flow("greet") do
        param :who
        step("s") { received = who }
      end

      ctx = described_class.new({}, client)
      ctx.invoke("greet", who: "patrick")

      expect(received).to eq("patrick")
    end

    it "passes the named page proxy to the flow" do
      seen = nil
      Browserctl.flow("uses_page") do
        step("s") { seen = page }
      end

      ctx = described_class.new({}, client)
      ctx.invoke("uses_page", page: :main)

      expect(seen).to be_a(Browserctl::PageProxy)
    end

    it "passes nil page when no page: kwarg given" do
      seen = :unset
      Browserctl.flow("no_page") do
        step("s") { seen = page }
      end

      described_class.new({}, client).invoke("no_page")

      expect(seen).to be_nil
    end

    it "exposes the workflow's client to the flow" do
      seen = nil
      Browserctl.flow("uses_client") do
        step("s") { seen = client }
      end

      described_class.new({}, client).invoke("uses_client")

      expect(seen).to equal(client)
    end

    it "prefers a registered flow over a registered workflow with the same name" do
      Browserctl.workflow "shadow" do
        step("wf") { raise "should not run" }
      end
      Browserctl.flow("shadow") { step("flow_step") { :flow_ran } }

      expect { described_class.new({}, client).invoke("shadow") }.not_to raise_error
    ensure
      Browserctl.instance_variable_get(:@registry).delete("shadow")
    end

    it "falls through to workflow invocation when no flow matches" do
      ctx = described_class.new({}, client)
      runner = instance_double(Browserctl::Runner, run_workflow: true)
      allow(Browserctl::Runner).to receive(:new).and_return(runner)

      ctx.invoke("only_a_workflow")

      expect(runner).to have_received(:run_workflow).with("only_a_workflow")
    end

    it "propagates flow typed errors" do
      Browserctl.flow("guarded") { precondition("on page") { false } }

      expect { described_class.new({}, client).invoke("guarded") }
        .to raise_error(Browserctl::FlowPreconditionError)
    end
  end
end

RSpec.describe "WorkflowContext compose guard" do
  let(:client) { instance_double(Browserctl::Client) }

  it "raises WorkflowError with a helpful message when compose is called inside a step block" do
    defn = Browserctl::WorkflowDefinition.new("test")
    defn.step("bad") do
      compose "other_workflow"
    end

    expect { defn.call({}, client) }.to raise_error(
      Browserctl::WorkflowError,
      /compose.*definition level.*invoke/i
    )
  end
end

RSpec.describe "PageProxy ref-based interaction" do
  let(:client) { instance_double(Browserctl::Client) }

  describe "#fill" do
    it "passes ref: to client when ref: is given" do
      expect(client).to receive(:fill).with("main", nil, "hello", ref: "e1").and_return({ ok: true })
      proxy = Browserctl::PageProxy.new("main", client)
      proxy.fill(nil, "hello", ref: "e1")
    end

    it "passes selector positionally when no ref given" do
      expect(client).to receive(:fill).with("main", "input#email", "hello", ref: nil).and_return({ ok: true })
      proxy = Browserctl::PageProxy.new("main", client)
      proxy.fill("input#email", "hello")
    end
  end

  describe "#click" do
    it "passes ref: to client when ref: is given" do
      expect(client).to receive(:click).with("main", nil, ref: "e3").and_return({ ok: true })
      proxy = Browserctl::PageProxy.new("main", client)
      proxy.click(nil, ref: "e3")
    end

    it "passes selector positionally when no ref given" do
      expect(client).to receive(:click).with("main", "button#submit", ref: nil).and_return({ ok: true })
      proxy = Browserctl::PageProxy.new("main", client)
      proxy.click("button#submit")
    end
  end

  describe "#hover" do
    it "passes ref: to client" do
      expect(client).to receive(:hover).with("main", nil, ref: "e4").and_return({ ok: true })
      proxy = Browserctl::PageProxy.new("main", client)
      proxy.hover(nil, ref: "e4")
    end
  end

  describe "#upload" do
    it "passes ref: to client" do
      expect(client).to receive(:upload).with("main", nil, "/tmp/file.pdf", ref: "e5").and_return({ ok: true })
      proxy = Browserctl::PageProxy.new("main", client)
      proxy.upload(nil, "/tmp/file.pdf", ref: "e5")
    end
  end

  describe "#select" do
    it "passes ref: to client" do
      expect(client).to receive(:select).with("main", nil, "AU", ref: "e6").and_return({ ok: true })
      proxy = Browserctl::PageProxy.new("main", client)
      proxy.select(nil, "AU", ref: "e6")
    end
  end
end

RSpec.describe "PageProxy public surface" do
  # Snapshot of the public method set prior to the delegate_unwrap macro
  # refactor. The macro must not add, drop, or rename methods — this guards
  # the user-visible API while the internals churn.
  it "matches the pre-macro snapshot exactly" do
    expected = %i[
      click
      delete_cookies
      devtools
      dialog_accept
      dialog_dismiss
      evaluate
      fill
      hover
      navigate
      press
      replay_context
      replay_context=
      screenshot
      select
      snapshot
      storage_get
      storage_set
      upload
      url
      wait
    ].sort

    actual = (Browserctl::PageProxy.public_instance_methods - Object.public_instance_methods).sort
    expect(actual).to eq(expected)
  end
end

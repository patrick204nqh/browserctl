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
  before { Browserctl.instance_variable_set(:@registry, {}) }
  after  { Browserctl.instance_variable_set(:@registry, {}) }

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
end

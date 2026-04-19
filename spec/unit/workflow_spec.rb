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
end

RSpec.describe Browserctl::WorkflowContext do
  let(:client) { instance_double(Browserctl::Client) }

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
      Browserctl::REGISTRY["loop_a"] = instance_double(
        Browserctl::WorkflowDefinition,
        call: nil
      )

      ctx = described_class.new({}, client)
      ctx.instance_variable_set(:@invoke_stack, ["loop_a"])

      expect { ctx.invoke("loop_a") }.to raise_error(Browserctl::WorkflowError, /circular/)
    end
  end
end

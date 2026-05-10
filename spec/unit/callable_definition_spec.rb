# frozen_string_literal: true

require "spec_helper"
require "browserctl/flow"
require "browserctl/workflow"

RSpec.describe Browserctl::CallableDefinition do
  before do
    Browserctl.flow_registry_reset!
    Browserctl.instance_variable_get(:@registry_mutex).synchronize do
      Browserctl.instance_variable_get(:@registry).clear
    end
  end

  describe "structural persistence whitelist" do
    it "FlowContext does not include ContextualPersistence (no store/fetch)" do
      expect(Browserctl::FlowContext.include?(Browserctl::ContextualPersistence)).to be(false)
      ctx = Browserctl::FlowContext.new(page: nil, params: {})
      expect(ctx.respond_to?(:store)).to be(false)
      expect(ctx.respond_to?(:fetch)).to be(false)
      expect(ctx.respond_to?(:save_state)).to be(false)
      expect(ctx.respond_to?(:load_state)).to be(false)
    end

    it "WorkflowContext mixes in ContextualPersistence (store/fetch present)" do
      expect(Browserctl::WorkflowContext.include?(Browserctl::ContextualPersistence)).to be(true)
      ctx = Browserctl::WorkflowContext.new({}, double("client"))
      expect(ctx).to respond_to(:store)
      expect(ctx).to respond_to(:fetch)
      expect(ctx).to respond_to(:save_state)
      expect(ctx).to respond_to(:load_state)
    end
  end

  describe "cross-type composition raises at definition time" do
    it "rejects a workflow composing a flow" do
      Browserctl.flow(:my_flow) do
        step :noop do
          :ok
        end
      end

      expect do
        Browserctl.workflow("composing_wf") do
          compose :my_flow
        end
      end.to raise_error(ArgumentError, /cannot compose flow/)
    end

    it "rejects a flow composing a workflow" do
      Browserctl.workflow("my_wf") do
        step("noop") { :ok }
      end

      expect do
        Browserctl.flow(:composing_flow) do
          compose :my_wf
        end
      end.to raise_error(ArgumentError, /cannot compose workflow/)
    end

    it "allows a workflow to compose another workflow" do
      Browserctl.workflow("base") do
        step("a") { :ok }
      end

      expect do
        Browserctl.workflow("composer") do
          compose :base
        end
      end.not_to raise_error
    end

    it "allows a flow to compose another flow" do
      Browserctl.flow(:base_flow) do
        step :a do
          :ok
        end
      end

      expect do
        Browserctl.flow(:composer_flow) do
          compose :base_flow
        end
      end.not_to raise_error
    end
  end

  describe "callable_kind" do
    it "exposes :flow on Flow definitions" do
      flow = Browserctl::Flow.new("f")
      expect(flow.callable_kind).to eq(:flow)
    end

    it "exposes :workflow on WorkflowDefinition" do
      defn = Browserctl::WorkflowDefinition.new("w")
      expect(defn.callable_kind).to eq(:workflow)
    end
  end
end

# frozen_string_literal: true

require "spec_helper"
require "browserctl/runner"

RSpec.describe Browserctl::Runner, "#run_workflow with check: true" do
  subject(:runner) { described_class.new }

  let(:client) { instance_double(Browserctl::Client) }

  before do
    allow(Browserctl::Client).to receive(:new).and_return(client)
    allow(Browserctl::Replay::Telemetry).to receive(:emit).and_return(0)
  end

  def define_workflow(name, &block)
    Browserctl.workflow(name) do
      step("do thing", &block)
    end
  end

  it "returns :clean and emits a no-drift report when no drift events are recorded" do
    define_workflow("clean_run") { nil }
    verdict = nil
    expect { verdict = runner.run_workflow("clean_run", check: true) }
      .to output(include('"drift": false')).to_stdout
    expect(verdict).to eq(:clean)
  end

  it "returns :drift and rolls drift events into the report" do
    define_workflow("drifty") do
      replay_context.record(command: :click, selector: "form .old",
                            matched_ref: "ea11111", score: 0.92, reason: "rematch")
    end
    captured = nil
    expect { captured = runner.run_workflow("drifty", check: true) }
      .to output(/"drift": true.*"rematches": 1/m).to_stdout
    expect(captured).to eq(:drift)
  end

  it "emits drift telemetry on the check path" do
    define_workflow("telemetry") do
      replay_context.record(command: :click, selector: ".old",
                            matched_ref: "eabc", score: 0.9, reason: "rematch")
    end
    expect(Browserctl::Replay::Telemetry).to receive(:emit) do |ctx, workflow:|
      expect(workflow).to eq("telemetry")
      expect(ctx.drift_events.size).to eq(1)
    end.and_return(1)
    expect { runner.run_workflow("telemetry", check: true) }.to output.to_stdout
  end

  it "does not emit telemetry when check is false" do
    define_workflow("no_check_telemetry") { nil }
    expect(Browserctl::Replay::Telemetry).not_to receive(:emit)
    runner.run_workflow("no_check_telemetry")
  end

  it "returns :fail when a step raises, regardless of drift" do
    define_workflow("breaks") { raise Browserctl::WorkflowError, "boom" }
    expect { runner.run_workflow("breaks", check: true) }
      .to raise_error(Browserctl::WorkflowError)
  end

  it "does not allocate a replay context when check is false" do
    seen = nil
    define_workflow("no_check") { seen = replay_context }
    expect(runner.run_workflow("no_check")).to eq(:clean)
    expect(seen).to be_nil
  end
end

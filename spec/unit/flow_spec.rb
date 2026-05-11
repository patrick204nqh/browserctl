# frozen_string_literal: true

require "spec_helper"
require "browserctl/flow"

RSpec.describe Browserctl::Flow do
  describe "DSL definition" do
    it "captures name, version, description, and minimum browserctl version" do
      flow = Browserctl.flow("login") do
        version "1.2.3"
        requires_browserctl "0.10.0"
        desc "Logs in"
      end

      expect(flow.name).to eq("login")
      expect(flow.version_string).to eq("1.2.3")
      expect(flow.min_browserctl_version).to eq("0.10.0")
      expect(flow.description).to eq("Logs in")
    end

    it "defaults version to 0.0.0 when omitted" do
      flow = Browserctl.flow("x") { desc "" }
      expect(flow.version_string).to eq("0.0.0")
    end

    it "rejects non-semver versions" do
      expect { Browserctl.flow("x") { version "1.2" } }
        .to raise_error(Browserctl::Error, /MAJOR\.MINOR\.PATCH/) do |e|
          expect(e.code).to eq(Browserctl::Error::Codes::INVALID_DSL_USAGE)
        end
    end

    it "rejects non-semver requires_browserctl" do
      expect { Browserctl.flow("x") { requires_browserctl "v1" } }
        .to raise_error(Browserctl::Error, /MAJOR\.MINOR\.PATCH/) do |e|
          expect(e.code).to eq(Browserctl::Error::Codes::INVALID_DSL_USAGE)
        end
    end

    it "requires a block at the top level" do
      expect { Browserctl.flow("x") }
        .to raise_error(Browserctl::Error, /requires a block/) do |e|
          expect(e.code).to eq(Browserctl::Error::Codes::INVALID_DSL_USAGE)
        end
    end

    it "requires blocks for step, precondition, postcondition, produces_state" do
      expect_dsl_block_required { Browserctl.flow("x") { step("s") } }
      expect_dsl_block_required { Browserctl.flow("x") { precondition("p") } }
      expect_dsl_block_required { Browserctl.flow("x") { postcondition("p") } }
      expect_dsl_block_required { Browserctl.flow("x") { produces_state } }
    end

    def expect_dsl_block_required(&block)
      expect(&block).to raise_error(Browserctl::Error, /requires a block/) do |e|
        expect(e.code).to eq(Browserctl::Error::Codes::INVALID_DSL_USAGE)
      end
    end

    it "coerces secret_ref params to secret: true" do
      flow = Browserctl.flow("x") { param :p, secret_ref: "env://X" }
      expect(flow.param_defs[:p].secret).to be true
    end
  end

  describe "#run param resolution" do
    it "passes provided params through" do
      received = nil
      Browserctl.flow("x") do
        param :user
        step("s") { received = user }
      end.run(user: "patrick")

      expect(received).to eq("patrick")
    end

    it "uses default when caller omits the param" do
      received = nil
      Browserctl.flow("x") do
        param :flag, default: 42
        step("s") { received = flag }
      end.run

      expect(received).to eq(42)
    end

    it "raises FlowParamError when a required param is missing" do
      flow = Browserctl.flow("x") do
        param :user, required: true
        step("s") { nil }
      end

      expect { flow.run }.to raise_error(Browserctl::FlowParamError, /requires param 'user'/) do |e|
        expect(e.code).to eq("flow_param_error")
      end
    end

    it "resolves secret_ref params via the SecretResolverRegistry" do
      allow(Browserctl::SecretResolverRegistry).to receive(:resolve).with("env://X").and_return("shhh")
      received = nil
      Browserctl.flow("x") do
        param :token, secret_ref: "env://X"
        step("s") { received = token }
      end.run

      expect(received).to eq("shhh")
      expect(Browserctl::SecretResolverRegistry).to have_received(:resolve).with("env://X")
    end

    it "lets SecretResolverError propagate from the registry" do
      allow(Browserctl::SecretResolverRegistry).to receive(:resolve)
        .and_raise(Browserctl::SecretResolverError, "boom")
      flow = Browserctl.flow("x") do
        param :token, secret_ref: "env://NOT_SET"
        step("s") { nil }
      end

      expect { flow.run }.to raise_error(Browserctl::SecretResolverError, "boom")
    end
  end

  describe "#run execution order" do
    it "runs precondition → steps → postcondition → produces_state" do
      log = []
      result = Browserctl.flow("x") do
        precondition("pre") do
          log << :pre
          true
        end
        step("s1")           { log << :s1 }
        step("s2")           { log << :s2 }
        postcondition("post") do
          log << :post
          true
        end
        produces_state do
          log << :state
          :payload
        end
      end.run

      expect(log).to eq(%i[pre s1 s2 post state])
      expect(result).to eq(:payload)
    end

    it "returns nil when no produces_state block is declared" do
      result = Browserctl.flow("x") { step("s") { nil } }.run
      expect(result).to be_nil
    end
  end

  describe "preconditions" do
    it "raises FlowPreconditionError on falsey return" do
      flow = Browserctl.flow("x") { precondition("on page") { false } }

      expect { flow.run }.to raise_error(Browserctl::FlowPreconditionError, /returned false/) do |e|
        expect(e.code).to eq("flow_precondition_failed")
      end
    end

    it "wraps raised errors as FlowPreconditionError" do
      flow = Browserctl.flow("x") { precondition("blow") { raise "bang" } }

      expect { flow.run }.to raise_error(Browserctl::FlowPreconditionError, /raised: bang/)
    end

    it "short-circuits before any step runs" do
      ran = false
      flow = Browserctl.flow("x") do
        precondition("guard") { false }
        step("s") { ran = true }
      end

      expect { flow.run }.to raise_error(Browserctl::FlowPreconditionError)
      expect(ran).to be false
    end
  end

  describe "postconditions" do
    it "raises FlowPostconditionError on falsey return" do
      flow = Browserctl.flow("x") do
        step("s") { nil }
        postcondition("done") { false }
      end

      expect { flow.run }.to raise_error(Browserctl::FlowPostconditionError, /returned false/) do |e|
        expect(e.code).to eq("flow_postcondition_failed")
      end
    end
  end

  describe "step retry and timeout" do
    it "retries up to retry_count times before raising" do
      attempts = 0
      Browserctl.flow("x") do
        step("flaky", retry_count: 2) do
          attempts += 1
          raise "still failing" if attempts < 3
        end
      end.run

      expect(attempts).to eq(3)
    end

    it "raises FlowStepError when retries are exhausted" do
      flow = Browserctl.flow("x") do
        step("always", retry_count: 1) { raise "nope" }
      end

      expect { flow.run }.to raise_error(Browserctl::FlowStepError, /step 'always' failed: nope/) do |e|
        expect(e.code).to eq("flow_step_failed")
      end
    end

    it "raises FlowStepError with a timeout message when a step exceeds timeout" do
      flow = Browserctl.flow("x") do
        step("slow", timeout: 0.05) { sleep 0.5 }
      end

      expect { flow.run }.to raise_error(Browserctl::FlowStepError, /timed out after 0\.05s/)
    end
  end

  describe "FlowContext" do
    it "exposes page, client, and params provided to #run" do
      page   = Object.new
      client = Object.new
      seen   = {}

      Browserctl.flow("x") do
        param :name
        step("s") do
          seen[:page] = page
          seen[:client] = client
          seen[:name] = name
        end
      end.run(page: page, client: client, name: "p")

      expect(seen).to eq(page: page, client: client, name: "p")
    end

    it "falls back to method_missing for undefined params" do
      flow = Browserctl.flow("x") do
        step("s") { undefined_thing }
      end

      expect { flow.run }.to raise_error(Browserctl::FlowStepError, /NoMethodError|undefined_thing/)
    end
  end
end

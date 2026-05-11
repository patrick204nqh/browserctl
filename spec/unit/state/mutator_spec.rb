# frozen_string_literal: true

require "spec_helper"
require "browserctl/state/mutator"

RSpec.describe Browserctl::State::Mutator do
  let(:client) { instance_double(Browserctl::Client) }

  before { Browserctl.flow_registry_reset! }
  after  { Browserctl.flow_registry_reset! }

  describe "#rotate" do
    let(:manifest) { { flow: "github_login", origins: ["https://github.com"] } }

    let(:flow_ran) { [] }

    before do
      ran = flow_ran
      Browserctl.flow("github_login") do
        version "1.2.3"
        param :username, required: true
        step("noop") { ran << username }
      end
    end

    it "runs the bound flow, re-saves the bundle, and returns a Result" do
      saved_args = nil
      allow(client).to receive(:state_info).with("github").and_return(ok: true, info: manifest)
      allow(client).to receive(:state_save) do |name, **kw|
        saved_args = [name, kw]
        { ok: true, path: "/tmp/x.bctl" }
      end

      result = described_class.new(client: client)
                              .rotate(name: "github", params: { username: "pat" })

      expect(flow_ran).to eq(["pat"])
      expect(saved_args).to eq([
                                 "github",
                                 { flow: "github_login", flow_version: "1.2.3",
                                   origins: ["https://github.com"] }
                               ])
      expect(result).to be_a(described_class::Result)
      expect(result.flow_name).to eq("github_login")
      expect(result.flow_version).to eq("1.2.3")
      expect(result.to_h).to include(ok: true, path: "/tmp/x.bctl", rotated_flow: "github_login")
    end

    it "merges params verbatim (caller hash drives the flow run)" do
      allow(client).to receive(:state_info).and_return(ok: true, info: manifest)
      allow(client).to receive(:state_save).and_return(ok: true)

      described_class.new(client: client).rotate(name: "github", params: { username: "alice" })

      expect(flow_ran).to eq(["alice"])
    end

    it "raises FlowError when the manifest has no bound flow" do
      allow(client).to receive(:state_info).with("x").and_return(ok: true, info: { origins: [] })

      expect { described_class.new(client: client).rotate(name: "x") }
        .to raise_error(Browserctl::FlowError, /no bound flow/)
    end

    it "raises FlowError when the bound flow is not registered" do
      allow(client).to receive(:state_info).with("x").and_return(ok: true, info: { flow: "missing" })

      expect { described_class.new(client: client).rotate(name: "x") }
        .to raise_error(Browserctl::FlowError, /not found in registry/)
    end

    it "raises FlowError when state_info returns an error" do
      allow(client).to receive(:state_info).with("x").and_return(error: "state 'x' not found")

      expect { described_class.new(client: client).rotate(name: "x") }
        .to raise_error(Browserctl::FlowError, /not found/)
    end

    it "does not call state_save when the flow lookup fails" do
      allow(client).to receive(:state_info).with("x").and_return(ok: true, info: { flow: "missing" })
      expect(client).not_to receive(:state_save)

      begin
        described_class.new(client: client).rotate(name: "x")
      rescue Browserctl::FlowError
        # expected
      end
    end
  end
end

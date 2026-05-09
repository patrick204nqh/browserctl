# frozen_string_literal: true

require "spec_helper"
require "json"
require "stringio"
require "browserctl/commands/state"

RSpec.describe Browserctl::Commands::State do
  let(:client) { instance_double(Browserctl::Client) }

  before { Browserctl.flow_registry_reset! }
  after  { Browserctl.flow_registry_reset! }

  describe ".run rotate" do
    it "runs the bound flow and re-saves the bundle" do
      flow_ran = false
      Browserctl.flow("github_login") do
        version "1.2.3"
        param :username, required: true
        step("noop") { flow_ran = true }
      end

      manifest = { flow: "github_login", origins: ["https://github.com"] }
      allow(client).to receive(:state_info).with("github").and_return(ok: true, info: manifest)
      allow(client).to receive(:state_save).with("github",
                                                 flow: "github_login",
                                                 flow_version: "1.2.3",
                                                 origins: ["https://github.com"])
                                           .and_return(ok: true, path: "/tmp/x.bctl")

      out = capture_stdout do
        described_class.run(client, %w[rotate github --username pat])
      end

      payload = JSON.parse(out)
      expect(payload["ok"]).to be(true)
      expect(payload["rotated_flow"]).to eq("github_login")
      expect(flow_ran).to be(true)
    end

    it "aborts when the manifest has no bound flow" do
      allow(client).to receive(:state_info).with("github").and_return(ok: true, info: { origins: [] })

      expect { described_class.run(client, %w[rotate github]) }
        .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
    end

    it "aborts when the bound flow is not registered" do
      allow(client).to receive(:state_info).with("github")
                                           .and_return(ok: true, info: { flow: "missing_flow" })

      expect { described_class.run(client, %w[rotate github]) }
        .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
    end

    it "surfaces an error from state_info" do
      allow(client).to receive(:state_info).with("github").and_return(error: "state 'github' not found")

      expect { described_class.run(client, %w[rotate github]) }
        .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
    end
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end

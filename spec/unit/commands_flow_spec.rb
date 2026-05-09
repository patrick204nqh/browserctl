# frozen_string_literal: true

require "spec_helper"
require "json"
require "tmpdir"
require "fileutils"
require "browserctl/commands/flow"

RSpec.describe Browserctl::Commands::Flow do
  let(:client) { instance_double(Browserctl::Client) }

  before { Browserctl.flow_registry_reset! }
  after  { Browserctl.flow_registry_reset! }

  describe ".run_list" do
    it "prints registered flows as JSON" do
      Browserctl.flow("alpha") do
        version "1.2.3"
        desc "first"
      end
      allow(Browserctl::FlowRegistry).to receive(:list)
        .and_return([{ name: "alpha", desc: "first", version: "1.2.3" }])

      out = capture_stdout { described_class.run(client, ["list"]) }
      payload = JSON.parse(out)

      expect(payload["flows"]).to eq([{ "name" => "alpha", "desc" => "first", "version" => "1.2.3" }])
    end
  end

  describe ".run_describe" do
    it "prints flow shape as pretty JSON" do
      Browserctl.flow("alpha") do
        version "2.0.0"
        desc "alpha"
        param :who, required: true
        precondition("on page") { true }
        step("greet") { nil }
        postcondition("done") { true }
        produces_state { :state }
      end

      out = capture_stdout { described_class.run(client, %w[describe alpha]) }
      payload = JSON.parse(out)

      expect(payload).to include(
        "name" => "alpha",
        "version" => "2.0.0",
        "desc" => "alpha",
        "preconditions" => ["on page"],
        "steps" => ["greet"],
        "postconditions" => ["done"],
        "produces_state" => true
      )
      expect(payload["params"]["who"]).to include("required" => true, "secret" => false)
    end

    it "exits when the flow is not found" do
      expect { described_class.run(client, %w[describe missing]) }
        .to raise_error(SystemExit)
    end
  end

  describe ".run_flow" do
    it "runs the named flow with kwargs and prints success JSON" do
      Browserctl.flow("alpha") do
        param :who
        step("s") { params[:who] }
      end

      out = capture_stdout { described_class.run(client, %w[run alpha --who patrick]) }
      payload = JSON.parse(out)

      expect(payload).to eq("ok" => true, "flow" => "alpha", "result" => nil)
    end

    it "passes a PageProxy when --page is given" do
      seen = nil
      Browserctl.flow("alpha") { step("s") { seen = page } }

      capture_stdout { described_class.run(client, %w[run alpha --page main]) }

      expect(seen).to be_a(Browserctl::PageProxy)
    end

    it "exits 1 with error JSON on FlowError" do
      Browserctl.flow("alpha") do
        param :who, required: true
        step("s") { nil }
      end

      original = $stdout
      $stdout = StringIO.new
      expect { described_class.run(client, %w[run alpha]) }
        .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      payload = JSON.parse($stdout.string)
      $stdout = original
      expect(payload).to include("ok" => false, "code" => "flow_param_error")
    end

    it "loads a flow from a file path" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "fileflow.rb")
        File.write(path, "Browserctl.flow('fileflow') { desc 'from file'; step('s') { nil } }\n")

        out = capture_stdout { described_class.run(client, ["run", path]) }
        payload = JSON.parse(out)

        expect(payload).to include("ok" => true, "flow" => "fileflow")
      end
    end

    it "merges --params file values with --key value pairs" do
      seen = {}
      Browserctl.flow("alpha") do
        param :a
        param :b
        step("s") do
          seen[:a] = params[:a]
          seen[:b] = params[:b]
        end
      end

      Dir.mktmpdir do |dir|
        params_path = File.join(dir, "p.json")
        File.write(params_path, JSON.generate(a: "from_file"))

        capture_stdout do
          described_class.run(client, ["run", "alpha", "--params", params_path, "--b", "from_cli"])
        end

        expect(seen).to eq(a: "from_file", b: "from_cli")
      end
    end
  end

  describe "subcommand dispatch" do
    it "aborts with usage when no subcommand given" do
      expect { described_class.run(client, []) }.to raise_error(SystemExit)
    end

    it "aborts on unknown subcommand" do
      expect { described_class.run(client, %w[zorp]) }.to raise_error(SystemExit)
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

# frozen_string_literal: true

require "json"
require "stringio"
require "spec_helper"
require "browserctl/commands/output_format"
require "browserctl/commands/page"
require "browserctl/commands/cookie"
require "browserctl/commands/storage"
require "browserctl/commands/state"
require "browserctl/commands/workflow"

# Per-command verification that all three --output modes are honoured for
# one command in each domain (page, cookie, storage, state, workflow).
# Drives the command modules directly with a stubbed client/runner so we
# don't need a live daemon.
RSpec.describe "Browserctl::Commands::OutputFormat (per-domain dispatch)" do
  before { Browserctl::Commands::OutputFormat.reset! }
  after  { Browserctl::Commands::OutputFormat.reset! }

  def with_format(mode)
    Browserctl::Commands::OutputFormat.current =
      Browserctl::Commands::OutputFormat::Formatter.new(mode)
    yield
  end

  def capture_io
    out = StringIO.new
    err = StringIO.new
    orig_out = $stdout
    orig_err = $stderr
    $stdout = out
    $stderr = err
    yield
    [out.string, err.string]
  ensure
    $stdout = orig_out
    $stderr = orig_err
  end

  shared_examples "honours --output across modes" do
    it "text mode prints payload.to_json + newline (byte-identical to legacy)" do
      with_format("text") do
        out, = capture_io { invoke }
        expect(out).to eq("#{payload.to_json}\n")
      end
    end

    it "json mode prints payload as JSON" do
      with_format("json") do
        out, = capture_io { invoke }
        expect(JSON.parse(out)).to eq(JSON.parse(payload.to_json))
      end
    end

    it "silent mode prints nothing on stdout" do
      with_format("silent") do
        out, = capture_io { invoke }
        expect(out).to eq("")
      end
    end
  end

  describe "page list" do
    let(:payload) { { pages: %w[main popup] } }
    let(:client) { instance_double(Browserctl::Client, page_list: payload) }

    define_method(:invoke) { Browserctl::Commands::Page.run(client, ["list"]) }

    include_examples "honours --output across modes"
  end

  describe "cookie list" do
    let(:payload) { { cookies: [{ name: "sid", value: "x" }] } }
    let(:client) { instance_double(Browserctl::Client, cookies: payload) }

    define_method(:invoke) { Browserctl::Commands::Cookie.run(client, %w[list main]) }

    include_examples "honours --output across modes"
  end

  describe "storage get" do
    let(:payload) { { value: "hello" } }
    let(:client) do
      instance_double(Browserctl::Client).tap do |c|
        allow(c).to receive(:storage_get).with("main", "k", store: "local").and_return(payload)
      end
    end

    define_method(:invoke) { Browserctl::Commands::Storage.run(client, %w[get main k]) }

    include_examples "honours --output across modes"
  end

  describe "state list" do
    let(:payload) { { states: %w[a b] } }
    let(:client) { instance_double(Browserctl::Client, state_list: payload) }

    define_method(:invoke) { Browserctl::Commands::State.run(client, ["list"]) }

    include_examples "honours --output across modes"
  end

  describe "workflow list" do
    let(:listing) { [{ name: "login", desc: "Login flow" }] }
    let(:payload) { { workflows: [{ name: "login", desc: "Login flow" }] } }
    let(:runner) { instance_double(Browserctl::Runner, list_workflows: listing) }

    define_method(:invoke) { Browserctl::Commands::Workflow.run(runner, ["list"]) }

    include_examples "honours --output across modes"
  end
end

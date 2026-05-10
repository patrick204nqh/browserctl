# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "browserctl/workflow/flow_wrapper"

RSpec.describe Browserctl::Workflow::FlowWrapper do
  def make_workflow(name, &block)
    block ||= -> {}
    Browserctl.workflow(name, &block)
    Browserctl.lookup_workflow(name)
  end

  describe ".render" do
    it "wraps a parameter-free workflow as a runnable flow" do
      defn = make_workflow("plain") { desc "does a thing" }
      ruby = described_class.render(defn)
      expect(ruby).to include('Browserctl.flow("plain")')
      expect(ruby).to include('version "1.0.0"')
      expect(ruby).to include('requires_browserctl "0.11.0"')
      expect(ruby).to include('desc "does a thing"')
      expect(ruby).to include('Browserctl::Runner.new.run_workflow("plain", **params)')
    end

    it "renders required, secret, default and secret_ref params" do
      defn = make_workflow("typed") do
        param :url,      required: true
        param :token,    secret: true
        param :limit,    default: 10
        param :api_key,  secret_ref: "op://Vault/Item/key"
      end
      ruby = described_class.render(defn)
      expect(ruby).to include("param :url, required: true")
      expect(ruby).to include("param :token, secret: true")
      expect(ruby).to include("param :limit, default: 10")
      expect(ruby).to include('param :api_key, secret_ref: "op://Vault/Item/key"')
      expect(ruby).not_to match(/param :api_key,.*secret: true/)
    end

    it "falls back to a default description when the workflow has none" do
      defn = make_workflow("no_desc")
      ruby = described_class.render(defn)
      expect(ruby).to include(%(desc "Promoted from workflow 'no_desc'"))
    end
  end

  describe ".write" do
    it "writes the rendered flow file under the configured directory" do
      Dir.mktmpdir do |dir|
        defn = make_workflow("writable") { desc "x" }
        path = described_class.write(defn, dir: dir)
        expect(path).to eq(File.join(dir, "writable.rb"))
        expect(File.read(path)).to include('Browserctl.flow("writable")')
      end
    end

    it "is idempotent under overwrite: true" do
      Dir.mktmpdir do |dir|
        defn = make_workflow("idem") { desc "first" }
        described_class.write(defn, dir: dir)
        defn2 = make_workflow("idem") { desc "second" }
        described_class.write(defn2, dir: dir)
        expect(File.read(File.join(dir, "idem.rb"))).to include('"second"')
      end
    end

    it "refuses to overwrite when overwrite: false" do
      Dir.mktmpdir do |dir|
        defn = make_workflow("guarded") { desc "x" }
        described_class.write(defn, dir: dir)
        expect do
          described_class.write(defn, dir: dir, overwrite: false)
        end.to raise_error(/already exists/)
      end
    end
  end

  describe ".render_param" do
    it "treats secret_ref as implying secret without emitting both flags" do
      param = Browserctl::ParamDef.new(
        name: :k, required: false, secret: true, default: nil, secret_ref: "env://K"
      )
      expect(described_class.render_param(param)).to eq(
        'param :k, secret_ref: "env://K"'
      )
    end
  end
end

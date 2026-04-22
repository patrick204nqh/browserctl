# frozen_string_literal: true

require "spec_helper"
require "browserctl/runner"
require "tmpdir"
require "json"

RSpec.describe Browserctl::Runner do
  subject(:runner) { described_class.new }

  describe ".load_params_file" do
    around do |example|
      Dir.mktmpdir do |dir|
        @tmp = dir
        example.run
      end
    end

    it "loads a YAML file and symbolizes keys" do
      path = File.join(@tmp, "params.yml")
      File.write(path, "email: user@test.com\ncount: 3\n")
      result = described_class.load_params_file(path)
      expect(result).to eq(email: "user@test.com", count: 3)
    end

    it "loads a .yaml extension" do
      path = File.join(@tmp, "params.yaml")
      File.write(path, "key: value\n")
      expect(described_class.load_params_file(path)).to eq(key: "value")
    end

    it "loads a JSON file and symbolizes keys" do
      path = File.join(@tmp, "params.json")
      File.write(path, JSON.generate(token: "abc", count: 5))
      result = described_class.load_params_file(path)
      expect(result).to eq(token: "abc", count: 5)
    end

    it "raises when file does not exist" do
      expect { described_class.load_params_file("/nonexistent/params.yml") }
        .to raise_error(/params file not found/)
    end

    it "raises on invalid YAML" do
      path = File.join(@tmp, "bad.yml")
      File.write(path, "key: [\nbad yaml")
      expect { described_class.load_params_file(path) }
        .to raise_error(/invalid YAML/)
    end

    it "raises on invalid JSON" do
      path = File.join(@tmp, "bad.json")
      File.write(path, "{not: valid json}")
      expect { described_class.load_params_file(path) }
        .to raise_error(/invalid JSON/)
    end

    it "raises on unsupported extension" do
      path = File.join(@tmp, "params.toml")
      File.write(path, "key = 'value'")
      expect { described_class.load_params_file(path) }
        .to raise_error(/unsupported params file format/)
    end
  end

  describe "#run_workflow with unsafe name" do
    it "raises for path-traversal names" do
      expect { runner.run_workflow("../../etc/passwd") }
        .to raise_error(Browserctl::WorkflowError, /invalid workflow name/)
    end

    it "raises for unregistered names with slashes" do
      expect { runner.run_workflow("foo/bar") }
        .to raise_error(Browserctl::WorkflowError, /invalid workflow name/)
    end

    it "runs a pre-registered workflow whose name contains a slash" do
      Browserctl.workflow("the_internet/login") { desc "test" }
      allow_any_instance_of(Browserctl::WorkflowDefinition).to receive(:call).and_return([])
      expect { runner.run_workflow("the_internet/login") }.not_to raise_error
    ensure
      Browserctl::REGISTRY.delete("the_internet/login")
    end

    it "raises for names with null bytes" do
      expect { runner.run_workflow("foo\x00bar") }
        .to raise_error(Browserctl::WorkflowError, /invalid workflow name/)
    end

    it "accepts safe names" do
      # workflow does not exist — error should be "not found" not "invalid name"
      expect { runner.run_workflow("my-workflow_01") }
        .to raise_error(RuntimeError, /not found/)
    end
  end
end

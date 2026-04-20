# frozen_string_literal: true

require "spec_helper"
require "browserctl/runner"

RSpec.describe Browserctl::Runner do
  subject(:runner) { described_class.new }

  describe "#run_workflow with unsafe name" do
    it "raises for path-traversal names" do
      expect { runner.run_workflow("../../etc/passwd") }
        .to raise_error(Browserctl::WorkflowError, /invalid workflow name/)
    end

    it "raises for names with slashes" do
      expect { runner.run_workflow("foo/bar") }
        .to raise_error(Browserctl::WorkflowError, /invalid workflow name/)
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

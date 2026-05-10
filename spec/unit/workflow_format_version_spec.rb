# frozen_string_literal: true

require "spec_helper"
require "browserctl/workflow"
require "browserctl/runner"
require "tmpdir"

RSpec.describe "workflow format version" do
  describe "Browserctl::WORKFLOW_FORMAT_VERSION" do
    it "is the integer 1 (current live version)" do
      expect(Browserctl::WORKFLOW_FORMAT_VERSION).to eq(1)
      expect(Browserctl::SUPPORTED_WORKFLOW_FORMAT_VERSIONS).to include(1)
    end
  end

  describe ".parse_workflow_format_version" do
    it "parses a `# format_version: N` header on the first line" do
      src = "# format_version: 1\nBrowserctl.workflow 'x' do\nend\n"
      expect(Browserctl.parse_workflow_format_version(src)).to eq(1)
    end

    it "parses the header after a `# frozen_string_literal: true` magic comment" do
      src = "# frozen_string_literal: true\n# format_version: 2\n\nBrowserctl.workflow 'x' do\nend\n"
      expect(Browserctl.parse_workflow_format_version(src)).to eq(2)
    end

    it "tolerates extra whitespace inside the comment body" do
      src = "#   format_version:   3\n"
      expect(Browserctl.parse_workflow_format_version(src)).to eq(3)
    end

    it "returns nil when no header is present in the leading comment block" do
      src = "# frozen_string_literal: true\n\nBrowserctl.workflow 'x' do\nend\n"
      expect(Browserctl.parse_workflow_format_version(src)).to be_nil
    end

    it "ignores a header that appears after code (must be in leading comment block)" do
      src = "Browserctl.workflow 'x' do\n  # format_version: 1\nend\n"
      expect(Browserctl.parse_workflow_format_version(src)).to be_nil
    end
  end

  describe ".verify_workflow_format_version!" do
    around do |example|
      Dir.mktmpdir do |dir|
        @tmp = dir
        example.run
      end
    end

    def write_workflow(content)
      path = File.join(@tmp, "wf.rb")
      File.write(path, content)
      path
    end

    it "is silent when the header is present and supported" do
      path = write_workflow("# frozen_string_literal: true\n# format_version: 1\n")
      expect { Browserctl.verify_workflow_format_version!(path) }.not_to output.to_stderr
    end

    it "warns to stderr when the header is missing" do
      path = write_workflow("# frozen_string_literal: true\n\nBrowserctl.workflow 'x' do\nend\n")
      expect { Browserctl.verify_workflow_format_version!(path) }
        .to output(/missing a `# format_version: N` header.*proceeding anyway/m).to_stderr
    end

    it "warns to stderr when the version is unsupported, including the value" do
      path = write_workflow("# format_version: 99\n")
      expect { Browserctl.verify_workflow_format_version!(path) }
        .to output(/format_version=99 is not supported.*proceeding anyway/m).to_stderr
    end

    it "does not raise on unsupported versions (warn-only)" do
      path = write_workflow("# format_version: 99\n")
      expect { Browserctl.verify_workflow_format_version!(path) }.not_to raise_error
    end

    it "returns the parsed integer when present" do
      path = write_workflow("# format_version: 1\n")
      expect { Browserctl.verify_workflow_format_version!(path) }
        .not_to output.to_stderr
      expect(Browserctl.verify_workflow_format_version!(path)).to eq(1)
    end
  end

  describe "Browserctl::Runner workflow loading" do
    around do |example|
      Dir.mktmpdir do |dir|
        @tmp = dir
        @workflows_dir = File.join(dir, ".browserctl", "workflows")
        FileUtils.mkdir_p(@workflows_dir)
        Dir.chdir(dir) { example.run }
      end
    end

    def write_workflow(name, content)
      path = File.join(@workflows_dir, "#{name}.rb")
      File.write(path, content)
      path
    end

    it "warns when loading a workflow file with a missing version header" do
      write_workflow("wf_missing_#{rand(1_000_000)}", <<~RUBY)
        # frozen_string_literal: true
        Browserctl.workflow "wf_missing_header" do
          desc "no header"
        end
      RUBY

      expect { Browserctl::Runner.new.list_workflows }
        .to output(/missing a `# format_version: N` header/).to_stderr
    end

    it "does not warn for a workflow file with the supported header" do
      write_workflow("wf_ok_#{rand(1_000_000)}", <<~RUBY)
        # frozen_string_literal: true
        # format_version: 1
        Browserctl.workflow "wf_ok_header" do
          desc "good"
        end
      RUBY

      expect { Browserctl::Runner.new.list_workflows }.not_to output.to_stderr
    end
  end
end

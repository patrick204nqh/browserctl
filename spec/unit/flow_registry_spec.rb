# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "browserctl/flow_registry"

RSpec.describe Browserctl::FlowRegistry do
  around do |ex|
    Dir.mktmpdir do |project_root|
      Dir.mktmpdir do |home|
        @project_root = project_root
        @home = home
        @user_dir = File.join(home, ".browserctl/flows")
        @stdlib_dir = File.join(project_root, "_stdlib")
        FileUtils.mkdir_p(File.join(project_root, ".browserctl/flows"))
        FileUtils.mkdir_p(@user_dir)
        FileUtils.mkdir_p(@stdlib_dir)
        Dir.chdir(project_root) { ex.run }
      end
    end
  end

  before do
    Browserctl.flow_registry_reset!
    allow(described_class).to receive_messages(user_dir: @user_dir, bundled_dir: @stdlib_dir)
  end

  def write_flow(dir, name, body = "step('s') { nil }")
    path = File.join(dir, "#{name}.rb")
    File.write(path, "Browserctl.flow(#{name.inspect}) do\n  desc 'from #{File.basename(dir)}'\n  #{body}\nend\n")
    path
  end

  describe ".resolve" do
    it "loads and returns a flow from the project dir" do
      write_flow("./.browserctl/flows", "alpha")

      flow = described_class.resolve("alpha")

      expect(flow).to be_a(Browserctl::Flow)
      expect(flow.name).to eq("alpha")
    end

    it "falls back to the user dir when project has no match" do
      write_flow(@user_dir, "userflow")

      flow = described_class.resolve("userflow")

      expect(flow.description).to eq("from flows")
    end

    it "falls back to the stdlib dir when project and user have no match" do
      write_flow(@stdlib_dir, "stdflow")

      flow = described_class.resolve("stdflow")

      expect(flow.description).to eq("from _stdlib")
    end

    it "returns nil when no file matches" do
      expect(described_class.resolve("missing")).to be_nil
    end

    it "returns the already-registered flow without re-loading" do
      Browserctl.flow("inmemory") { desc "live" }

      flow = described_class.resolve("inmemory")

      expect(flow.description).to eq("live")
    end

    it "rejects unsafe flow names" do
      expect { described_class.resolve("../etc/passwd") }
        .to raise_error(Browserctl::Error) { |err|
          expect(err.message).to match(/invalid flow name/)
          expect(err.code).to eq(Browserctl::Error::Codes::INVALID_DSL_USAGE)
        }
    end

    it "prefers the project file when both project and stdlib define the same name" do
      write_flow(@stdlib_dir, "shared", "desc 'stdlib version'")
      write_flow("./.browserctl/flows", "shared", "desc 'project version'")

      flow = described_class.resolve("shared")

      expect(flow.description).to eq("project version")
    end
  end

  describe ".load_all" do
    it "loads every flow from every search dir, project winning collisions" do
      write_flow(@stdlib_dir, "shared", "desc 'stdlib'")
      write_flow(@user_dir, "shared", "desc 'user'")
      write_flow("./.browserctl/flows", "shared", "desc 'project'")
      write_flow(@user_dir, "user_only")
      write_flow(@stdlib_dir, "std_only")

      snapshot = described_class.load_all

      expect(snapshot.keys).to contain_exactly("shared", "user_only", "std_only")
      expect(snapshot["shared"].description).to eq("project")
    end

    it "returns an empty snapshot when no dirs have flows" do
      expect(described_class.load_all).to be_empty
    end
  end

  describe ".list" do
    it "returns name, desc, and version for each flow" do
      File.write(
        "./.browserctl/flows/listed.rb",
        "Browserctl.flow('listed') do\n  version '2.1.0'\n  desc 'L'\n  step('s') { nil }\nend\n"
      )

      entry = described_class.list.find { |h| h[:name] == "listed" }

      expect(entry).to eq(name: "listed", desc: "L", version: "2.1.0")
    end
  end
end

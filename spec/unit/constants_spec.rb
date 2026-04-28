# frozen_string_literal: true

require "tmpdir"
require "browserctl/constants"

RSpec.describe Browserctl do
  describe ".socket_path" do
    it "returns default path when no name given" do
      expect(described_class.socket_path).to end_with("browserd.sock")
    end

    it "returns named path when name given" do
      expect(described_class.socket_path("agent-1")).to end_with("agent-1.sock")
    end

    it "named path is under ~/.browserctl" do
      expect(described_class.socket_path("x")).to include(".browserctl")
    end
  end

  describe ".pid_path" do
    it "returns default path when no name given" do
      expect(described_class.pid_path).to end_with("browserd.pid")
    end

    it "returns named path when name given" do
      expect(described_class.pid_path("agent-1")).to end_with("agent-1.pid")
    end
  end

  describe "backward-compatible constants" do
    it "SOCKET_PATH equals socket_path with no args" do
      expect(Browserctl::SOCKET_PATH).to eq described_class.socket_path
    end

    it "PID_PATH equals pid_path with no args" do
      expect(Browserctl::PID_PATH).to eq described_class.pid_path
    end
  end

  describe ".next_daemon_name" do
    before do
      @tmpdir = Dir.mktmpdir
      stub_const("Browserctl::BROWSERCTL_DIR", @tmpdir)
    end

    after { FileUtils.rm_rf(@tmpdir) }

    it "returns nil when the default socket does not exist" do
      expect(described_class.next_daemon_name).to be_nil
    end

    it "returns 'd1' when the default socket exists" do
      FileUtils.touch(described_class.socket_path)
      expect(described_class.next_daemon_name).to eq("d1")
    end

    it "returns 'd2' when default and d1 sockets both exist" do
      FileUtils.touch(described_class.socket_path)
      FileUtils.touch(described_class.socket_path("d1"))
      expect(described_class.next_daemon_name).to eq("d2")
    end
  end

  describe ".all_daemon_names" do
    before do
      @tmpdir = Dir.mktmpdir
      stub_const("Browserctl::BROWSERCTL_DIR", @tmpdir)
    end

    after { FileUtils.rm_rf(@tmpdir) }

    it "maps browserd.sock to nil and named sockets to their names" do
      FileUtils.touch(described_class.socket_path)
      FileUtils.touch(described_class.socket_path("work"))
      names = described_class.all_daemon_names
      expect(names).to include(nil)
      expect(names).to include("work")
    end

    it "returns empty array when no sockets exist" do
      expect(described_class.all_daemon_names).to eq([])
    end
  end
end

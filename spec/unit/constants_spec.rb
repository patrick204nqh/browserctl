# frozen_string_literal: true

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
end

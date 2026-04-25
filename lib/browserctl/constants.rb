# frozen_string_literal: true

module Browserctl
  BROWSERCTL_DIR   = File.expand_path("~/.browserctl")
  IDLE_TTL         = 30 * 60
  # Increment when a breaking wire protocol change ships (new field names, removed commands, changed response shapes).
  # Clients read this from `ping` to verify compatibility before sending commands.
  PROTOCOL_VERSION = "1"

  def self.socket_path(name = nil)
    File.join(BROWSERCTL_DIR, name ? "#{name}.sock" : "browserd.sock")
  end

  def self.pid_path(name = nil)
    File.join(BROWSERCTL_DIR, name ? "#{name}.pid" : "browserd.pid")
  end

  def self.log_path(name = nil)
    File.join(BROWSERCTL_DIR, name ? "#{name}.log" : "browserd.log")
  end

  # Backward-compatible constants
  SOCKET_PATH = socket_path
  PID_PATH    = pid_path
end

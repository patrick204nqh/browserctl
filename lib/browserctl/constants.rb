# frozen_string_literal: true

module Browserctl
  BROWSERCTL_DIR = File.expand_path("~/.browserctl")
  IDLE_TTL       = 30 * 60

  def self.socket_path(name = nil)
    File.join(BROWSERCTL_DIR, name ? "#{name}.sock" : "browserd.sock")
  end

  def self.pid_path(name = nil)
    File.join(BROWSERCTL_DIR, name ? "#{name}.pid" : "browserd.pid")
  end

  # Backward-compatible constants
  SOCKET_PATH = socket_path
  PID_PATH    = pid_path
end

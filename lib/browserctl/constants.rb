# frozen_string_literal: true

module Browserctl
  BROWSERCTL_DIR   = File.expand_path("~/.browserctl")
  IDLE_TTL         = 30 * 60
  # Increment when a breaking wire protocol change ships (new field names, removed commands, changed response shapes).
  # Clients read this from `ping` to verify compatibility before sending commands.
  PROTOCOL_VERSION = "2"

  def self.socket_path(name = nil)
    File.join(BROWSERCTL_DIR, name ? "#{name}.sock" : "browserd.sock")
  end

  def self.pid_path(name = nil)
    File.join(BROWSERCTL_DIR, name ? "#{name}.pid" : "browserd.pid")
  end

  def self.log_path(name = nil)
    File.join(BROWSERCTL_DIR, name ? "#{name}.log" : "browserd.log")
  end

  # Returns nil when the default (unnamed) slot is free; otherwise returns "d1", "d2", etc.
  def self.next_daemon_name
    return nil unless File.exist?(socket_path)

    1.upto(99) do |i|
      return "d#{i}" unless File.exist?(socket_path("d#{i}"))
    end
    raise "too many running daemons (limit: 99)"
  end

  def self.all_daemon_sockets
    Dir[File.join(BROWSERCTL_DIR, "*.sock")]
  end

  def self.all_daemon_names
    all_daemon_sockets.map { |f| File.basename(f, ".sock") }
                      .map { |n| n == "browserd" ? nil : n }
  end

  # Backward-compatible constants
  SOCKET_PATH = socket_path
  PID_PATH    = pid_path
end

# frozen_string_literal: true

module Browserctl
  SOCKET_PATH = File.expand_path("~/.browserctl/browserd.sock")
  PID_PATH    = File.expand_path("~/.browserctl/browserd.pid")
  IDLE_TTL    = 30 * 60
end

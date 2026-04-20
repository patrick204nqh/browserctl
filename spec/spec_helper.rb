# frozen_string_literal: true

require "browserctl"
require "browserctl/server"
require "browserctl/client"

Browserctl.logger = Logger.new(File::NULL)

module BrowserctlHelpers
  def start_daemon(headed: false, name: nil)
    socket = Browserctl.socket_path(name)
    pid_f  = Browserctl.pid_path(name)

    @daemon_pid = fork do
      $stdout.reopen(File::NULL)
      $stderr.reopen(File::NULL)
      Browserctl::Server.new(
        headless: !headed,
        socket_path: socket,
        pid_path: pid_f
      ).run
    end

    deadline = Time.now + 10
    sleep 0.1 until File.exist?(socket) || Time.now > deadline
    raise "browserd failed to start" unless File.exist?(socket)

    Browserctl::Client.new(socket)
  end

  def stop_daemon
    return unless @daemon_pid

    Process.kill("INT", @daemon_pid)
    deadline = Time.now + 5
    loop do
      Process.wait(@daemon_pid, Process::WNOHANG)
      break if Time.now > deadline

      sleep 0.1
    end
    Process.kill("KILL", @daemon_pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  ensure
    [Browserctl.socket_path, Browserctl.pid_path].each do |f|
      File.unlink(f)
    rescue StandardError
      nil
    end
    @daemon_pid = nil
  end
end

RSpec.configure do |config|
  config.include BrowserctlHelpers

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
  config.warnings = true
end

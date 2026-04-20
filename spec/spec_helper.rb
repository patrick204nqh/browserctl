# frozen_string_literal: true

require "browserctl"
require "browserctl/server"
require "browserctl/client"

Browserctl.logger = ::Logger.new(File::NULL)

module BrowserctlHelpers
  def start_daemon(headed: false)
    @daemon_pid = fork do
      $stdout.reopen(File::NULL)
      $stderr.reopen(File::NULL)
      Browserctl::Server.new(headless: !headed).run
    end

    # Wait until socket appears (max 10s)
    deadline = Time.now + 10
    sleep 0.1 until File.exist?(Browserctl::SOCKET_PATH) || Time.now > deadline
    raise "browserd failed to start" unless File.exist?(Browserctl::SOCKET_PATH)

    Browserctl::Client.new
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
    begin
      File.unlink(Browserctl::SOCKET_PATH)
    rescue StandardError
      nil
    end
    begin
      File.unlink(Browserctl::PID_PATH)
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

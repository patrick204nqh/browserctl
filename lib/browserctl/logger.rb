# frozen_string_literal: true

require "logger"

module Browserctl
  LEVEL_MAP = {
    "debug" => ::Logger::DEBUG,
    "info" => ::Logger::INFO,
    "warn" => ::Logger::WARN,
    "error" => ::Logger::ERROR
  }.freeze

  def self.logger
    @logger ||= build_logger("info")
  end

  def self.logger=(instance)
    @logger = instance
  end

  def self.build_logger(level_name)
    log = ::Logger.new($stderr)
    log.level    = LEVEL_MAP.fetch(level_name.to_s.downcase, ::Logger::INFO)
    log.progname = "browserd"
    log.formatter = proc { |sev, t, prog, msg| "#{t.strftime('%Y-%m-%dT%H:%M:%S')} #{sev[0]} [#{prog}] #{msg}\n" }
    log
  end
end

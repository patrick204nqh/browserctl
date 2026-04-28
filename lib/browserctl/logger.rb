# frozen_string_literal: true

require "logger"
require "fileutils"

module Browserctl
  LEVEL_MAP = {
    "debug" => ::Logger::DEBUG,
    "info" => ::Logger::INFO,
    "warn" => ::Logger::WARN,
    "error" => ::Logger::ERROR
  }.freeze

  class MultiLogger
    def initialize(*loggers)
      @loggers = loggers
    end

    # Delegate to each logger; swallow individual write failures so a broken file
    # logger never crashes the daemon or drops a client response.
    def debug(msg = nil, &) = @loggers.each { |l| l.debug(msg, &) rescue nil }
    def info(msg = nil, &)  = @loggers.each { |l| l.info(msg, &)  rescue nil }
    def warn(msg = nil, &)  = @loggers.each { |l| l.warn(msg, &)  rescue nil }
    def error(msg = nil, &) = @loggers.each { |l| l.error(msg, &) rescue nil }

    def level = @loggers.first&.level

    def level=(lvl)
      @loggers.each { |l| l.level = lvl }
    end
  end

  def self.logger
    @logger ||= build_logger("info")
  end

  def self.logger=(instance)
    @logger = instance
  end

  def self.build_logger(level_name, log_path: nil)
    level = LEVEL_MAP.fetch(level_name.to_s.downcase, ::Logger::INFO)
    formatter = proc { |sev, t, prog, msg| "#{t.strftime('%Y-%m-%dT%H:%M:%S')} #{sev[0]} [#{prog}] #{msg}\n" }

    stderr_log = make_logger($stderr, level, formatter)
    return stderr_log unless log_path

    FileUtils.mkdir_p(File.dirname(log_path), mode: 0o700)
    FileUtils.touch(log_path)
    File.chmod(0o600, log_path)
    file_log = make_logger(log_path, level, formatter)
    MultiLogger.new(stderr_log, file_log)
  end

  def self.make_logger(device, level, formatter)
    log = ::Logger.new(device)
    log.level     = level
    log.progname  = "browserd"
    log.formatter = formatter
    log
  end
  private_class_method :make_logger
end

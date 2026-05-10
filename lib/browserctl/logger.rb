# frozen_string_literal: true

require "logger"
require "fileutils"
require "json"
require "time"

module Browserctl
  LEVEL_MAP = {
    "debug" => ::Logger::DEBUG,
    "info" => ::Logger::INFO,
    "warn" => ::Logger::WARN,
    "error" => ::Logger::ERROR
  }.freeze

  # JSONL rotation policy. Stdlib `Logger` rotates by size when given an
  # integer `shift_age` and `shift_size`.
  LOG_SHIFT_AGE  = 10                # keep last 10 rotated files
  LOG_SHIFT_SIZE = 10 * 1024 * 1024  # rotate at 10MB

  # Resolved at call time so tests can override BROWSERCTL_DIR via stub_const.
  def self.log_dir
    File.join(BROWSERCTL_DIR, "logs")
  end

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

  # Formats every log line as a single JSON object: {ts, level, component, msg, ...}.
  # If the message is a Hash, its keys are merged so callers can attach
  # structured context, e.g. `logger.info(event: "x", session: id)`.
  class JsonlFormatter
    def initialize(component:)
      @component = component
    end

    def call(severity, time, _progname, msg)
      record = {
        ts: time.utc.iso8601(3),
        level: severity,
        component: @component
      }

      case msg
      when Hash
        explicit = msg[:msg] || msg["msg"]
        record[:msg] = explicit if explicit
        record.merge!(msg.reject { |k, _| k.to_s == "msg" })
      when Exception
        record[:msg] = "#{msg.class}: #{msg.message}"
        record[:backtrace] = Array(msg.backtrace).first(10)
      else
        record[:msg] = msg.to_s
      end

      "#{JSON.generate(record)}\n"
    end
  end

  def self.logger
    @logger ||= build_logger("info")
  end

  def self.logger=(instance)
    @logger = instance
  end

  # Build a logger that writes:
  #   - human-readable lines to stderr (unchanged behaviour)
  #   - human-readable lines to log_path: when given (the daemon tail file)
  #   - structured JSONL lines to ~/.browserctl/logs/<component>.log (rotating
  #     10 files x 10MB) when jsonl: is true
  #
  # JSONL output is purely additive — existing stderr/stdout behaviour is
  # preserved so scripted callers see no change.
  def self.build_logger(level_name, log_path: nil, component: "daemon", jsonl: true)
    level = LEVEL_MAP.fetch(level_name.to_s.downcase, ::Logger::INFO)
    text_formatter = proc do |sev, t, prog, msg|
      "#{t.strftime('%Y-%m-%dT%H:%M:%S')} #{sev[0]} [#{prog}] #{format_text_msg(msg)}\n"
    end

    loggers = [make_logger($stderr, level, text_formatter)]

    if log_path
      FileUtils.mkdir_p(File.dirname(log_path), mode: 0o700)
      FileUtils.touch(log_path)
      File.chmod(0o600, log_path)
      loggers << make_logger(log_path, level, text_formatter)
    end

    if jsonl
      jsonl_logger = build_jsonl_logger(level, component)
      loggers << jsonl_logger if jsonl_logger
    end

    loggers.length == 1 ? loggers.first : MultiLogger.new(*loggers)
  end

  # Returns a stdlib Logger writing JSON-Lines records to
  # ~/.browserctl/logs/<component>.log with size-based rotation. Returns nil
  # (and stays silent) if the directory cannot be created so logging never
  # crashes the daemon.
  # LogDevice that suppresses stdlib's "# Logfile created on ..." header so
  # the resulting file is pure JSON Lines.
  class HeaderlessLogDevice < ::Logger::LogDevice
    def add_log_header(_file); end
  end

  def self.build_jsonl_logger(level, component)
    dir = log_dir
    FileUtils.mkdir_p(dir, mode: 0o700)
    path = File.join(dir, "#{component}.log")
    device = HeaderlessLogDevice.new(path, shift_age: LOG_SHIFT_AGE, shift_size: LOG_SHIFT_SIZE)
    log = ::Logger.new(device)
    log.level     = level
    log.progname  = component
    log.formatter = JsonlFormatter.new(component: component)
    log
  rescue StandardError
    nil
  end

  def self.format_text_msg(msg)
    case msg
    when Hash      then (msg[:msg] || msg["msg"] || msg.inspect).to_s
    when Exception then "#{msg.class}: #{msg.message}"
    else                msg.to_s
    end
  end
  private_class_method :format_text_msg

  def self.make_logger(device, level, formatter)
    log = ::Logger.new(device)
    log.level     = level
    log.progname  = "browserd"
    log.formatter = formatter
    log
  end
  private_class_method :make_logger
end

# frozen_string_literal: true

require "json"
require "date"
require "fileutils"
require "tmpdir"

module Browserctl
  class Recording
    RECORDINGS_DIR = File.join(Dir.tmpdir, "browserctl-recordings")
    STATE_FILE     = File.expand_path("~/.browserctl/active_recording")

    RECORDABLE = %w[open_page goto fill click screenshot evaluate].freeze

    def self.start(name)
      FileUtils.mkdir_p(RECORDINGS_DIR)
      File.write(STATE_FILE, name)
      FileUtils.rm_f(log_path(name))
      name
    end

    def self.stop
      name = active
      raise "no active recording — run: browserctl record start <name>" unless name

      File.unlink(STATE_FILE)
      name
    end

    def self.active
      File.exist?(STATE_FILE) ? File.read(STATE_FILE).strip : nil
    end

    def self.append(cmd, **attrs)
      name = active
      return unless name
      return unless RECORDABLE.include?(cmd.to_s)
      # ref-based interactions have no replayable selector — skip them
      return if %w[click fill].include?(cmd.to_s) && attrs[:selector].nil?

      File.open(log_path(name), "a") do |f|
        f.puts JSON.generate({ cmd: cmd.to_s }.merge(attrs.transform_keys(&:to_s)))
      end
    end

    def self.generate_workflow(name, output_path: nil)
      log = log_path(name)
      raise "no recording found for '#{name}'" unless File.exist?(log)

      lines = File.readlines(log).map { |l| JSON.parse(l, symbolize_names: true) }
      ruby  = build_workflow_ruby(name, lines)
      File.write(output_path, ruby) if output_path
      FileUtils.rm_f(log)
      ruby
    end

    class << self
      private

      def log_path(name)
        File.join(RECORDINGS_DIR, "#{name}.jsonl")
      end

      def build_workflow_ruby(name, commands)
        steps = commands.map { |c| build_step(c) }.join("\n\n")
        <<~RUBY
          # frozen_string_literal: true

          Browserctl.workflow #{name.inspect} do
            desc "Recorded on #{Date.today}"

          #{steps.gsub(/^/, '  ')}
          end
        RUBY
      end

      def build_step(cmd)
        label, body = step_parts(cmd)
        "step #{label.inspect} do\n  #{body}\nend"
      end

      def step_parts(cmd)
        page = cmd[:name]
        case cmd[:cmd]
        when "open_page"
          ["open #{page}", "page(:#{page}).goto(#{cmd[:url].inspect})"]
        when "goto"
          ["goto #{page}", "page(:#{page}).goto(#{cmd[:url].inspect})"]
        when "fill"
          ["fill #{cmd[:selector]} on #{page}",
           "page(:#{page}).fill(#{cmd[:selector].inspect}, #{cmd[:value].inspect})"]
        when "click"
          ["click #{cmd[:selector]} on #{page}",
           "page(:#{page}).click(#{cmd[:selector].inspect})"]
        when "screenshot"
          ["screenshot #{page}", "page(:#{page}).screenshot"]
        when "evaluate"
          ["eval on #{page}", "page(:#{page}).evaluate(#{cmd[:expression].inspect})"]
        else
          ["#{cmd[:cmd]} on #{page}", "# unrecognised command: #{cmd.inspect}"]
        end
      end
    end
  end
end

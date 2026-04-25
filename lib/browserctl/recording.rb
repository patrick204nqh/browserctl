# frozen_string_literal: true

require "json"
require "date"
require "fileutils"
require "tmpdir"
require "uri"

module Browserctl
  class Recording
    RECORDINGS_DIR = File.join(Dir.tmpdir, "browserctl-recordings")
    STATE_FILE     = File.expand_path("~/.browserctl/active_recording")

    RECORDABLE = %w[open_page goto fill click screenshot evaluate].freeze

    SENSITIVE_PARAM_PATTERN = /\A(token|key|secret|auth|code|access_token|api_key|client_secret|state)\z/ix

    def self.start(name)
      FileUtils.mkdir_p(RECORDINGS_DIR, mode: 0o700)
      FileUtils.mkdir_p(File.dirname(STATE_FILE))
      File.write(STATE_FILE, name)
      FileUtils.rm_f(log_path(name))
      FileUtils.touch(log_path(name))
      File.chmod(0o600, log_path(name))
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

      if %w[click fill].include?(cmd.to_s) && attrs[:selector].nil?
        record_ref_interaction(name, cmd.to_s, attrs)
        return
      end

      attrs = prepare_attrs(cmd.to_s, attrs)

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

      ref_count = lines.count { |l| l[:cmd] == "_ref_interaction" }
      if ref_count.positive?
        warn "Warning: #{ref_count} ref-based interaction(s) were captured but cannot be replayed by ref."
        warn "Search the generated workflow for 'TODO: ref-based' and replace with stable CSS selectors."
      end

      ruby
    ensure
      FileUtils.rm_f(log) if log
    end

    class << self
      private

      def log_path(name)
        File.join(RECORDINGS_DIR, "#{name}.jsonl")
      end

      def record_ref_interaction(recording_name, cmd, attrs)
        entry = { cmd: "_ref_interaction", action: cmd, ref: attrs[:ref], name: attrs[:name] }
        File.open(log_path(recording_name), "a") do |f|
          f.puts JSON.generate(entry)
        end
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

        if body.nil?
          page_sym = cmd[:name].to_s.gsub(/[^a-zA-Z0-9_]/, "_")
          action   = cmd[:action].to_s.gsub(/[^a-z_]/, "")
          return "# TODO: ref-based #{action} on #{cmd[:name].inspect} (ref: #{cmd[:ref].inspect}) — " \
                 "replace with a stable CSS selector\n" \
                 "# step #{label.inspect} do\n" \
                 "#   page(:#{page_sym}).#{action}(\"YOUR_SELECTOR_HERE\")\n" \
                 "# end"
        end

        url = cmd[:url].to_s
        if url.include?("[REDACTED]")
          "# NOTE: sensitive query params were redacted during recording\nstep #{label.inspect} do\n  #{body}\nend"
        else
          "step #{label.inspect} do\n  #{body}\nend"
        end
      end

      def step_parts(cmd)
        return ref_interaction_parts(cmd) if cmd[:cmd] == "_ref_interaction"
        return selector_parts(cmd) if %w[fill click].include?(cmd[:cmd])

        page = cmd[:name]
        case cmd[:cmd]
        when "open_page"  then ["open #{page}", "page(:#{page}).goto(#{cmd[:url].inspect})"]
        when "goto"       then ["goto #{page}", "page(:#{page}).goto(#{cmd[:url].inspect})"]
        when "screenshot" then ["screenshot #{page}", "page(:#{page}).screenshot"]
        when "evaluate"   then ["eval on #{page}", "page(:#{page}).evaluate(#{cmd[:expression].inspect})"]
        else ["#{cmd[:cmd]} on #{page}", "# unrecognised command: #{cmd.inspect}"]
        end
      end

      def ref_interaction_parts(cmd)
        ["TODO: ref-based #{cmd[:action]} on #{cmd[:name]} (ref: #{cmd[:ref]})", nil]
      end

      def selector_parts(cmd)
        page = cmd[:name]
        case cmd[:cmd]
        when "fill"
          ["fill #{cmd[:selector]} on #{page}",
           "page(:#{page}).fill(#{cmd[:selector].inspect}, params[:fill_value])"]
        when "click"
          ["click #{cmd[:selector]} on #{page}",
           "page(:#{page}).click(#{cmd[:selector].inspect})"]
        end
      end

      def prepare_attrs(cmd, attrs)
        attrs = attrs.except(:value) if cmd == "fill"
        attrs[:url] = redact_url(attrs[:url]) if %w[goto open_page].include?(cmd) && attrs[:url]
        attrs
      end

      def redact_url(url)
        uri = URI.parse(url)
        return url if uri.query.nil?

        uri.query = uri.query.gsub(/([^&=]+)=([^&]*)/) do |full_match|
          raw_key = ::Regexp.last_match(1)
          key = URI.decode_www_form_component(raw_key)
          key =~ SENSITIVE_PARAM_PATTERN ? "#{raw_key}=[REDACTED]" : full_match
        end
        uri.to_s
      rescue URI::InvalidURIError
        url
      end
    end
  end
end

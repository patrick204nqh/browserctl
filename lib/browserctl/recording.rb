# frozen_string_literal: true

require "json"
require "date"
require "time"
require "fileutils"
require "tmpdir"
require "uri"

module Browserctl
  class Recording
    RECORDINGS_DIR = File.join(Dir.tmpdir, "browserctl-recordings")
    STATE_FILE     = File.expand_path("~/.browserctl/active_recording")

    RECORDABLE = %w[page_open navigate fill click screenshot evaluate].freeze

    SENSITIVE_PARAM_PATTERN = /\A(token|key|secret|auth|code|access_token|api_key|client_secret|state)\z/ix

    # Selector tokens that signal a fill is targeting a secret-shaped field.
    # The captured group (or matched substring) is used as the inferred field
    # name; that name later drives the generated `secret_ref:` placeholder.
    SECRET_FIELD_PATTERN = /\b(password|passwd|api[_-]?key|token|secret|otp|pin|client[_-]?secret|access[_-]?token)\b/i

    # Conservative thresholds for inferring an explicit wait between recorded
    # steps. Gaps shorter than the threshold come from natural input cadence;
    # gaps above it usually mean the page actually had work to do.
    WAIT_THRESHOLD_SECONDS = 1.5
    WAIT_PADDING_SECONDS   = 5
    WAIT_FLOOR_SECONDS     = 5

    # Bumped when the recording log shape changes in a way that older
    # tooling (workflow generate, replay) cannot read.
    LOG_FORMAT = "v0.11"

    def self.start(name)
      FileUtils.mkdir_p(RECORDINGS_DIR, mode: 0o700)
      FileUtils.mkdir_p(File.dirname(STATE_FILE))
      File.write(STATE_FILE, name)
      FileUtils.rm_f(log_path(name))
      FileUtils.touch(log_path(name))
      File.chmod(0o600, log_path(name))
      File.open(log_path(name), "a") do |f|
        f.puts JSON.generate(
          cmd: "_meta",
          log_format: LOG_FORMAT,
          recording: name,
          started_at: Time.now.utc.iso8601
        )
      end
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

    def self.append(cmd, response: nil, **attrs)
      name = active
      return unless name
      return unless RECORDABLE.include?(cmd.to_s)

      if %w[click fill].include?(cmd.to_s) && attrs[:selector].nil?
        record_ref_interaction(name, cmd.to_s, attrs, response)
        return
      end

      attrs = prepare_attrs(cmd.to_s, attrs)
      entry = { cmd: cmd.to_s, ts: now }.merge(attrs.transform_keys(&:to_s))
      entry.merge!(replay_metadata(response)) if response

      File.open(log_path(name), "a") do |f|
        f.puts JSON.generate(entry)
      end
    end

    def self.generate_workflow(name, output_path: nil, keep_log: false)
      log = log_path(name)
      raise "no recording found for '#{name}'" unless File.exist?(log)

      raw   = File.readlines(log).map { |l| JSON.parse(l, symbolize_names: true) }
      lines = raw.reject { |l| l[:cmd] == "_meta" }
      ruby  = build_workflow_ruby(name, lines)
      File.write(output_path, ruby) if output_path
      warn_about_ref_interactions(lines)
      ruby
    ensure
      FileUtils.rm_f(log) if log && !keep_log
    end

    def self.warn_about_ref_interactions(lines)
      ref_count = lines.count { |l| l[:cmd] == "_ref_interaction" }
      return unless ref_count.positive?

      warn "Warning: #{ref_count} ref-based interaction(s) were captured but cannot be replayed by ref."
      warn "Search the generated workflow for 'TODO: ref-based' and replace with stable CSS selectors."
    end

    class << self
      private

      def log_path(name)
        File.join(RECORDINGS_DIR, "#{name}.jsonl")
      end

      def record_ref_interaction(recording_name, cmd, attrs, response)
        entry = { cmd: "_ref_interaction", ts: now, action: cmd, ref: attrs[:ref], name: attrs[:name] }
        entry.merge!(replay_metadata(response)) if response
        File.open(log_path(recording_name), "a") do |f|
          f.puts JSON.generate(entry)
        end
      end

      # Pulls the replay-relevant fields out of a daemon response. Each
      # is optional — older daemons or non-resolving commands may omit
      # any of them.
      def now
        Time.now.utc.to_f
      end

      def replay_metadata(response)
        meta = {}
        meta[:ref]                = response[:ref]                if response[:ref]
        meta[:fingerprint]        = response[:fingerprint]        if response[:fingerprint]
        meta[:snapshot_id]        = response[:snapshot_id]        if response[:snapshot_id]
        meta[:postcondition_hint] = response[:postcondition_hint] if response[:postcondition_hint]
        meta.transform_keys(&:to_s)
      end

      def build_workflow_ruby(name, commands)
        steps   = annotated_steps(commands).join("\n\n")
        secrets = commands.map { |c| c[:secret_field] }.compact.uniq
        header  = secret_header(secrets)
        <<~RUBY
          # frozen_string_literal: true
          #{header}
          Browserctl.workflow #{name.inspect} do
            desc "Recorded on #{Date.today}"
          #{secrets.map { |f| "  param :secret_#{f}, secret: true" }.join("\n")}
          #{steps.gsub(/^/, '  ')}
          end
        RUBY
      end

      # Walks the recorded events and inserts an inferred wait step before
      # selector-driven actions whose preceding gap exceeds the threshold.
      # Returns the rendered step strings in order.
      def annotated_steps(commands)
        commands.each_with_index.flat_map do |cmd, i|
          rendered = []
          if i.positive? && (wait = inferred_wait_step(commands[i - 1], cmd))
            rendered << wait
          end
          rendered << build_step(cmd)
          rendered
        end
      end

      def inferred_wait_step(prev, current)
        return nil unless %w[fill click].include?(current[:cmd])
        return nil unless current[:selector]

        delta = elapsed(prev, current)
        return nil unless delta && delta >= WAIT_THRESHOLD_SECONDS

        timeout = [WAIT_FLOOR_SECONDS, delta.ceil + WAIT_PADDING_SECONDS].max
        page = current[:name]
        sel  = current[:selector]
        <<~RUBY.chomp
          # inferred wait: prior step took ~#{format('%.1f', delta)}s
          step "wait for #{sel} on #{page}" do
            page(:#{page}).wait(#{sel.inspect}, timeout: #{timeout})
          end
        RUBY
      end

      def elapsed(prev, current)
        return nil unless prev && current && prev[:ts] && current[:ts]

        current[:ts] - prev[:ts]
      end

      def secret_header(secrets)
        return "" if secrets.empty?

        lines = ["# TODO: review the following secret-shaped fields detected during recording.",
                 "# Configure a secret_ref: source for each before running:"]
        secrets.each { |f| lines << "#   - secret_#{f}" }
        "\n#{lines.join("\n")}\n"
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

        prefix = []
        prefix << "# NOTE: sensitive query params were redacted during recording" \
          if cmd[:url].to_s.include?("[REDACTED]")
        prefix << "# fingerprint fallback: #{cmd[:fingerprint].to_json}" if cmd[:fingerprint]

        head = prefix.empty? ? "" : "#{prefix.join("\n")}\n"
        "#{head}step #{label.inspect} do\n  #{body}\nend"
      end

      def step_parts(cmd)
        return ref_interaction_parts(cmd) if cmd[:cmd] == "_ref_interaction"
        return selector_parts(cmd) if %w[fill click].include?(cmd[:cmd])

        page = cmd[:name]
        case cmd[:cmd]
        when "page_open"  then ["open #{page}", "page(:#{page}).navigate(#{cmd[:url].inspect})"]
        when "navigate"   then ["navigate #{page}", "page(:#{page}).navigate(#{cmd[:url].inspect})"]
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
          value_arg = cmd[:secret_field] ? "params[:secret_#{cmd[:secret_field]}]" : "params[:fill_value]"
          ["fill #{cmd[:selector]} on #{page}",
           "page(:#{page}).fill(#{cmd[:selector].inspect}, #{value_arg})"]
        when "click"
          ["click #{cmd[:selector]} on #{page}",
           "page(:#{page}).click(#{cmd[:selector].inspect})"]
        end
      end

      def prepare_attrs(cmd, attrs)
        if cmd == "fill"
          attrs = attrs.except(:value)
          field = infer_secret_field(attrs[:selector])
          if field
            attrs[:secret_hint]  = true
            attrs[:secret_field] = field
          end
        end
        attrs[:url] = redact_url(attrs[:url]) if %w[navigate page_open].include?(cmd) && attrs[:url]
        attrs
      end

      def infer_secret_field(selector)
        return nil unless selector

        match = selector.match(SECRET_FIELD_PATTERN)
        return nil unless match

        match[1].downcase.gsub(/[^a-z0-9]/, "_")
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

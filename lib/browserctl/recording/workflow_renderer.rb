# frozen_string_literal: true

require "date"
require "uri"

module Browserctl
  class Recording
    # Renders a recording log into the Ruby source of a workflow. Pure
    # function over the parsed log entries — no I/O, no clock, no globals.
    #
    # Carved out of `Recording` so the facade stays focused on dispatch;
    # the step-rendering rules (selector vs ref, inferred waits, URL and
    # snapshot postconditions, secret param wiring) all live here.
    module WorkflowRenderer
      # Conservative thresholds for inferring an explicit wait between
      # recorded steps. Gaps shorter than the threshold come from natural
      # input cadence; gaps above it usually mean the page actually had
      # work to do.
      WAIT_THRESHOLD_SECONDS = 1.5
      WAIT_PADDING_SECONDS   = 5
      WAIT_FLOOR_SECONDS     = 5

      module_function

      # Returns the Ruby source string for the workflow named `name`,
      # given the parsed (non-meta) command entries.
      def render(name, commands)
        steps   = annotated_steps(commands).join("\n\n")
        secrets = commands.map { |c| c[:secret_field] }.compact.uniq
        header  = secret_header(secrets)
        <<~RUBY
          # frozen_string_literal: true
          # format_version: #{Browserctl::WORKFLOW_FORMAT_VERSION}
          #{header}
          Browserctl.workflow #{name.inspect} do
            desc "Recorded on #{Date.today}"
          #{secrets.map { |f| "  param :secret_#{f}, secret: true" }.join("\n")}
          #{steps.gsub(/^/, '  ')}
          end
        RUBY
      end

      # Walks the recorded events and emits the rendered step strings,
      # interleaving inferred waits before selector-driven actions whose
      # preceding gap exceeds WAIT_THRESHOLD_SECONDS, and inferred URL
      # postconditions after click/fill steps that triggered navigation.
      def annotated_steps(commands)
        last_url = {}
        commands.each_with_index.flat_map do |cmd, i|
          rendered = []
          if i.positive? && (wait = inferred_wait_step(commands[i - 1], cmd))
            rendered << wait
          end
          rendered << build_step(cmd)
          if (post = url_postcondition_step(cmd, last_url))
            rendered << post
          end
          if (snap = snapshot_postcondition_step(cmd))
            rendered << snap
          end
          update_last_url!(cmd, last_url)
          rendered
        end
      end

      # Emits a postcondition assertion when a click/fill resulted in a URL
      # change. Compares the canonical (scheme+host+path) form so query
      # strings and fragments don't make every replay flaky.
      def url_postcondition_step(cmd, last_url)
        return nil unless %w[click fill].include?(cmd[:cmd])
        return nil unless cmd[:postcondition_hint] && cmd[:postcondition_hint][:url]

        page = cmd[:name]
        observed = cmd[:postcondition_hint][:url]
        prior    = last_url[page]
        return nil if canonical_url(observed) == canonical_url(prior)

        prefix = canonical_url(observed)
        return nil unless prefix

        <<~RUBY.chomp
          step "assert url after #{cmd[:cmd]} on #{page}" do
            current = page(:#{page}).url
            assert current.start_with?(#{prefix.inspect}), "expected URL to start with #{prefix}, got \#{current}"
          end
        RUBY
      end

      # Emits an assert_snapshot_stable step when the recording captured a
      # post-step DOM digest. Under workflow run --check the helper records
      # drift on mismatch instead of raising, so a wiggly page surfaces in
      # the report rather than failing the run outright.
      def snapshot_postcondition_step(cmd)
        return nil unless %w[click fill].include?(cmd[:cmd])
        return nil unless cmd[:post_snapshot_digest]

        page = cmd[:name]
        digest = cmd[:post_snapshot_digest]
        <<~RUBY.chomp
          step "assert post-snapshot stable on #{page}" do
            assert_snapshot_stable(:#{page}, expected_digest: #{digest.inspect})
          end
        RUBY
      end

      def update_last_url!(cmd, last_url)
        case cmd[:cmd]
        when "navigate", "page_open"
          last_url[cmd[:name]] = cmd[:url] if cmd[:url]
        when "click", "fill"
          observed = cmd[:postcondition_hint] && cmd[:postcondition_hint][:url]
          last_url[cmd[:name]] = observed if observed
        end
      end

      def canonical_url(url)
        return nil if url.nil? || url.empty?

        uri = URI.parse(url)
        path = uri.path.to_s
        path = "/" if path.empty?
        "#{uri.scheme}://#{uri.host}#{path}"
      rescue URI::InvalidURIError
        nil
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

        lines = ["# REVIEW: the following secret-shaped fields were detected during recording.",
                 "# Configure a secret_ref: source for each before running:"]
        secrets.each { |f| lines << "#   - secret_#{f}" }
        "\n#{lines.join("\n")}\n"
      end

      def build_step(cmd)
        label, body = step_parts(cmd)

        if body.nil?
          page_sym = cmd[:name].to_s.gsub(/[^a-zA-Z0-9_]/, "_")
          action   = cmd[:action].to_s.gsub(/[^a-z_]/, "")
          return "# REVIEW: ref-based #{action} on #{cmd[:name].inspect} (ref: #{cmd[:ref].inspect}) — " \
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
        ["REVIEW: ref-based #{cmd[:action]} on #{cmd[:name]} (ref: #{cmd[:ref]})", nil]
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
    end
  end
end

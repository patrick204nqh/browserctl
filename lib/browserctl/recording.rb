# frozen_string_literal: true

require "tmpdir"
require_relative "errors"
require_relative "error/codes"

module Browserctl
  # Captures a sequence of daemon commands as a JSONL log and renders it
  # back out as a Ruby workflow file. This class is the public facade;
  # the focused responsibilities live under `Browserctl::Recording::*`:
  #
  # - `Recording::State`            — singleton over the on-disk marker.
  # - `Recording::Redactor`         — secret-aware redaction.
  # - `Recording::LogWriter`        — log file I/O and JSONL formatting.
  # - `Recording::WorkflowRenderer` — log-to-Ruby workflow translation.
  class Recording
    RECORDINGS_DIR = File.join(Dir.tmpdir, "browserctl-recordings")
    STATE_FILE     = File.expand_path("~/.browserctl/active_recording")

    # Recording-log format version, written into the `_meta` header and
    # validated when generate_workflow loads a recording. See
    # docs/reference/format-versions.md.
    RECORDING_FORMAT_VERSION = 1
    SUPPORTED_FORMAT_VERSIONS = [RECORDING_FORMAT_VERSION].freeze

    # Bumped when the recording log shape changes in a way that older
    # tooling (workflow generate, replay) cannot read.
    LOG_FORMAT = "v0.11"

    RECORDABLE = %w[page_open navigate fill click screenshot evaluate].freeze

    def self.start(name)
      LogWriter.init_log(name)
      State.write(name)
      name
    end

    def self.stop
      State.clear!
    end

    def self.active
      State.active
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

      LogWriter.append_entry(name, entry)
    end

    def self.generate_workflow(name, output_path: nil, keep_log: false)
      log = LogWriter.log_path(name)
      raise Browserctl::Error, "no recording found for '#{name}'" unless File.exist?(log)

      raw   = LogWriter.read_entries(name)
      LogWriter.verify_format_version!(raw, path: log)
      lines = raw.reject { |l| l[:cmd] == "_meta" }
      ruby  = WorkflowRenderer.render(name, lines)
      File.write(output_path, ruby) if output_path
      warn_about_ref_interactions(lines)
      ruby
    ensure
      LogWriter.delete_log(name) unless keep_log
    end

    def self.warn_about_ref_interactions(lines)
      ref_count = lines.count { |l| l[:cmd] == "_ref_interaction" }
      return unless ref_count.positive?

      warn "Warning: #{ref_count} ref-based interaction(s) were captured but cannot be replayed by ref."
      warn "Search the generated workflow for 'TODO: ref-based' and replace with stable CSS selectors."
    end

    class << self
      private

      def now
        Time.now.utc.to_f
      end

      def record_ref_interaction(recording_name, cmd, attrs, response)
        entry = { cmd: "_ref_interaction", ts: now, action: cmd, ref: attrs[:ref], name: attrs[:name] }
        entry.merge!(replay_metadata(response)) if response
        LogWriter.append_entry(recording_name, entry)
      end

      # Pulls the replay-relevant fields out of a daemon response. Each
      # is optional — older daemons or non-resolving commands may omit
      # any of them.
      def replay_metadata(response)
        meta = {}
        meta[:ref]                  = response[:ref]                  if response[:ref]
        meta[:fingerprint]          = response[:fingerprint]          if response[:fingerprint]
        meta[:snapshot_id]          = response[:snapshot_id]          if response[:snapshot_id]
        meta[:postcondition_hint]   = response[:postcondition_hint]   if response[:postcondition_hint]
        meta[:post_snapshot_digest] = response[:post_snapshot_digest] if response[:post_snapshot_digest]
        meta.transform_keys(&:to_s)
      end

      def prepare_attrs(cmd, attrs)
        attrs = attrs.except(:capture_post_snapshot)
        if cmd == "fill"
          attrs = attrs.except(:value)
          field = Redactor.infer_secret_field(attrs[:selector])
          if field
            attrs[:secret_hint]  = true
            attrs[:secret_field] = field
          end
        end
        attrs[:url] = Redactor.redact_url(attrs[:url]) if %w[navigate page_open].include?(cmd) && attrs[:url]
        attrs
      end
    end
  end
end

require_relative "recording/state"
require_relative "recording/redactor"
require_relative "recording/log_writer"
require_relative "recording/workflow_renderer"

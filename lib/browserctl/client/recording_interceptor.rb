# frozen_string_literal: true

require_relative "../recording"

module Browserctl
  class Client
    # Bridges Client#call to the Recording subsystem. Keeps Client itself a
    # pure IPC shim — Recording is pluggable via constructor injection.
    class RecordingInterceptor
      def initialize(recording: Browserctl::Recording)
        @recording = recording
      end

      # Whether recording is currently active. Call sites that need to vary
      # their request shape (e.g. click/fill passing capture_post_snapshot:)
      # can ask without touching Recording directly.
      def active?
        @recording.active
      end

      # Returns `true` when active, `nil` otherwise. Matches the shape that
      # click/fill historically passed as the `capture_post_snapshot` param.
      def capture_post_snapshot_flag
        return true if active?

        nil
      end

      # Called after a successful Client#call to append the command and
      # response to the active recording log. No-op if the response was
      # not ok (recording only captures successful interactions).
      def append(cmd, response:, params: {})
        return unless response[:ok]

        @recording.append(cmd, response: response, **params)
      end
    end
  end
end

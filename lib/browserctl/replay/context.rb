# frozen_string_literal: true

module Browserctl
  module Replay
    # Per-page replay context carried by PageProxy during a workflow run
    # generated from a recording.
    #
    # Holds the recorded fingerprint for each selector that the workflow
    # interacts with. When a selector-driven command fails with
    # selector_not_found at replay time, the proxy looks up the fingerprint
    # here and asks FingerprintMatcher to find a candidate in the live
    # snapshot. The matched element's stable ref is then re-used to retry
    # the original command.
    #
    # Drift events (rematches, threshold misses) are accumulated on the
    # context so the surrounding workflow runner can render them into a
    # drift report at end-of-run.
    class Context
      DriftEvent = Data.define(:command, :selector, :matched_ref, :score, :reason)

      attr_reader :drift_events

      def initialize(fingerprints: {})
        @fingerprints = fingerprints
        @drift_events = []
      end

      def fingerprint_for(selector)
        @fingerprints[selector]
      end

      def record(command:, selector:, matched_ref: nil, score: nil, reason: nil)
        @drift_events << DriftEvent.new(
          command: command, selector: selector,
          matched_ref: matched_ref, score: score, reason: reason
        )
      end
    end
  end
end

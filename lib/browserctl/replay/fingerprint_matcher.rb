# frozen_string_literal: true

module Browserctl
  module Replay
    # Scores candidate snapshot entries against a recorded fingerprint and
    # returns the best match above a configurable threshold.
    #
    # Inputs are the wire-shape fingerprints emitted by Snapshot::Fingerprint:
    #   { text:, role:, neighbors: [...], position: { index:, depth: } }
    #
    # Score is a weighted sum in [0.0, 1.0]:
    #   text      0.40   (exact match; case-insensitive)
    #   role      0.20   (exact match)
    #   neighbors 0.25   (Jaccard over the neighbor sets)
    #   position  0.15   (proximity in (index, depth) space)
    #
    # Defaults reflect the v0.11 acceptance bar: text + role together (0.60)
    # are enough to clear the default threshold, so a renamed neighbor or a
    # shifted index doesn't break replay.
    class FingerprintMatcher
      DEFAULT_THRESHOLD = 0.6
      WEIGHTS = { text: 0.40, role: 0.20, neighbors: 0.25, position: 0.15 }.freeze

      Match = Struct.new(:candidate, :score, keyword_init: true)

      def initialize(threshold: DEFAULT_THRESHOLD, weights: WEIGHTS)
        @threshold = threshold
        @weights = weights
      end

      # Returns the highest-scoring candidate entry above the threshold, or
      # nil if no candidate qualifies. `candidates` must be an array of
      # snapshot entries (hashes with a :fingerprint key). The returned
      # Match wraps the candidate hash and the numeric score.
      def best(target_fp, candidates)
        scored = candidates
                 .map { |c| Match.new(candidate: c, score: score(target_fp, c[:fingerprint])) }
                 .sort_by { |m| -m.score }

        winner = scored.first
        return nil unless winner && winner.score >= @threshold

        winner
      end

      def score(target, candidate)
        return 0.0 unless target && candidate

        (@weights[:text] * text_score(target[:text], candidate[:text])) +
          (@weights[:role]      * bool_score(target[:role] == candidate[:role])) +
          (@weights[:neighbors] * jaccard(target[:neighbors], candidate[:neighbors])) +
          (@weights[:position] * position_score(target[:position], candidate[:position]))
      end

      private

      def text_score(target, candidate)
        return 0.0 if target.nil? || candidate.nil? || target.empty? || candidate.empty?

        target.downcase.strip == candidate.downcase.strip ? 1.0 : 0.0
      end

      def bool_score(flag) = flag ? 1.0 : 0.0

      def jaccard(target, candidate)
        target = Array(target)
        candidate = Array(candidate)
        return 1.0 if target.empty? && candidate.empty?
        return 0.0 if target.empty? || candidate.empty?

        inter = (target & candidate).size
        union = (target | candidate).size
        union.zero? ? 0.0 : inter.to_f / union
      end

      def position_score(target, candidate)
        return 0.0 unless target && candidate

        idx_d = (target[:index].to_i - candidate[:index].to_i).abs
        depth_d = (target[:depth].to_i - candidate[:depth].to_i).abs
        # Soft falloff: 1.0 when identical, ~0 once they're 4+ apart in either axis.
        [1.0 - ((idx_d + depth_d) / 8.0), 0.0].max
      end
    end
  end
end

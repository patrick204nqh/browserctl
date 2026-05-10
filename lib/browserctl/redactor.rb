# frozen_string_literal: true

module Browserctl
  # Redacts known secret values from arbitrary strings.
  #
  # Used by `browserctl trace` to ensure traces are safe to attach to issues
  # by default. Secret values are sourced from two places:
  #   1. ENV variables whose names match well-known secret patterns
  #      (`*_TOKEN`, `*_KEY`, `*_SECRET`, `*_PASSWORD`).
  #   2. Values captured at runtime by `SecretResolverRegistry` (in-memory
  #      only — never persisted).
  #
  # Replacement marker is the literal `[REDACTED]`. We considered including
  # a sha256 prefix to distinguish values, but that doubles the surface area
  # for accidental leakage (a determined attacker could brute-force short
  # secrets from the prefix), and the timeline is more scannable with a
  # uniform marker.
  class Redactor
    MARKER = "[REDACTED]"
    MIN_LENGTH = 4
    ENV_PATTERNS = [/_TOKEN\z/, /_KEY\z/, /_SECRET\z/, /_PASSWORD\z/].freeze

    # @param secrets [Array<String>] secret values to redact.
    def initialize(secrets: [])
      # Filter empty / too-short values; longest-first to avoid partial
      # overlaps (e.g. redacting "abcd" before "abcdef" would leave "ef").
      @secrets = secrets
                 .compact
                 .map(&:to_s)
                 .reject { |s| s.length < MIN_LENGTH }
                 .uniq
                 .sort_by { |s| -s.length }
    end

    # @param string [String, nil]
    # @return [String, nil]
    def redact(string)
      return string if string.nil?

      result = string.to_s
      @secrets.each { |secret| result = result.gsub(secret, MARKER) }
      result
    end

    def empty?
      @secrets.empty?
    end

    # Build a Redactor from the current ENV using well-known patterns.
    # Optionally merges in additional values (e.g. from runtime instrumentation).
    def self.from_env(env: ENV, extra: [])
      values = env.each_with_object([]) do |(name, value), acc|
        acc << value if ENV_PATTERNS.any? { |re| name =~ re }
      end
      new(secrets: values + Array(extra))
    end
  end
end

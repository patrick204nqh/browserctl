# frozen_string_literal: true

require_relative "errors"

module Browserctl
  # Format-version header convention.
  #
  # Every persisted browserctl artifact declares its format version on the very
  # first line as `version: <int>`. This module is the convention's single
  # source of truth; per-format adoption (bundle, recording, workflow) lands in
  # later WS-1 PRs. See `docs/reference/format-versions.md`.
  module FormatVersion
    HEADER_RE = /\Aversion:\s*(\d+)\s*\z/

    module_function

    # Parse the version header from an IO or String. Returns the Integer
    # version. Raises Browserctl::ProtocolMismatch if the header is missing or
    # malformed.
    def parse(io_or_string)
      first_line = io_or_string.respond_to?(:gets) ? io_or_string.gets : io_or_string.to_s.each_line.first
      raise ProtocolMismatch, "missing version header" if first_line.nil?

      match = HEADER_RE.match(first_line.chomp)
      raise ProtocolMismatch, "malformed version header: #{first_line.inspect}" unless match

      Integer(match[1])
    end

    # Returns the canonical header string for a given integer version.
    def stamp(version:)
      unless version.is_a?(Integer) && version >= 0
        raise Browserctl::Error.new(
          "version must be a non-negative Integer",
          code: Browserctl::Error::Codes::INVALID_FORMAT_VERSION,
          context: { value: version }
        )
      end

      "version: #{version}\n"
    end
  end
end

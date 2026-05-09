# frozen_string_literal: true

require "uri"
require_relative "../errors"

module Browserctl
  module State
    # Pluggable transport for moving .bctl bundles in and out of remote
    # systems. Each transport responds to:
    #
    #   .scheme   String — URI scheme it handles ("file", "s3", "op", ...)
    #   #handles?(uri)  -> Boolean
    #   #available?     -> Boolean (e.g. CLI tool present, network reachable)
    #   #read(uri)      -> binary String (the bundle bytes)
    #   #write(uri, blob) -> nil; raises on failure
    #
    # Transports are matched by URI scheme. A bare path with no scheme falls
    # through to the FileTransport.
    module Transport
      class TransportError < Browserctl::Error; def self.default_code = "transport_error" end

      class << self
        def registry
          @registry ||= []
        end

        def register(transport)
          registry << transport
          transport
        end

        def for(uri)
          parsed = parse(uri)
          match  = registry.find { |t| t.handles?(parsed) }
          raise TransportError, "no transport for #{uri.inspect}" unless match

          unless match.available?
            scheme = parsed.scheme || "file"
            raise TransportError, "transport for '#{scheme}://' is not available — install the underlying CLI"
          end

          [match, parsed]
        end

        def parse(uri)
          uri.is_a?(URI) ? uri : URI.parse(uri.to_s)
        rescue URI::InvalidURIError
          # bare path with characters URI rejects — treat as file
          URI.parse("file://#{uri}")
        end
      end

      class Base
        def self.scheme = raise NotImplementedError

        def handles?(parsed)
          parsed.scheme.nil? || parsed.scheme == self.class.scheme
        end

        def available? = true
      end
    end
  end
end

# frozen_string_literal: true

require "fileutils"
require_relative "../transport"

module Browserctl
  module State
    module Transports
      # Default transport — reads/writes plain files. Handles bare paths and
      # `file://` URIs. Always available.
      class File < Transport::Base
        def self.scheme = "file"

        def read(parsed)
          path = local_path(parsed)
          raise Transport::TransportError, "file not found: #{path}" unless ::File.exist?(path)

          ::File.binread(path)
        end

        def write(parsed, blob)
          path = local_path(parsed)
          FileUtils.mkdir_p(::File.dirname(path))
          ::File.open(path, "wb", 0o600) { |f| f.write(blob) }
        end

        def local_path(parsed)
          ::File.expand_path(parsed.path.to_s.empty? ? parsed.opaque.to_s : parsed.path)
        end
      end
    end
  end
end

Browserctl::State::Transport.register(Browserctl::State::Transports::File.new)

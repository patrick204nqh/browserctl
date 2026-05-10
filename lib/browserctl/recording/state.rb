# frozen_string_literal: true

require "fileutils"
require_relative "../errors"
require_relative "../error/codes"

module Browserctl
  class Recording
    # Singleton over the on-disk marker (`STATE_FILE`) that tracks which
    # recording, if any, is currently active. Carved out of `Recording` so
    # the facade stays focused on dispatch.
    module State
      module_function

      # Returns the active recording name, or nil when no marker exists.
      # Reads the constant lazily so RSpec `stub_const` calls on the parent
      # `Recording::STATE_FILE` continue to take effect.
      def active
        path = Browserctl::Recording::STATE_FILE
        File.exist?(path) ? File.read(path).strip : nil
      end

      # Writes the marker for `name`. Caller is responsible for any
      # additional setup (e.g. log initialisation).
      def write(name)
        path = Browserctl::Recording::STATE_FILE
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, name)
        name
      end

      # Removes the marker. Raises Browserctl::Error when no recording is
      # active. The message is preserved verbatim from the pre-split
      # facade so existing specs and CLI surfaces stay stable.
      def clear!
        name = active
        raise Browserctl::Error, "no active recording — run: browserctl recording start <name>" unless name

        File.unlink(Browserctl::Recording::STATE_FILE)
        name
      end
    end
  end
end

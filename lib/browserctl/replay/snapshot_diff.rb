# frozen_string_literal: true

require "digest"

module Browserctl
  module Replay
    # Stable digest + element-set comparison for post-step snapshots.
    #
    # The digest is intentionally cheap and stable across cosmetic DOM noise:
    # only the (selector, role, tag) triples drive the hash, sorted to remove
    # ordering effects. That's enough to flag structural drift (a step that
    # used to land on /dashboard now lands on /login) without flapping on
    # every reflow or class rename.
    module SnapshotDiff
      module_function

      def digest(snapshot)
        return nil if snapshot.nil?

        keys = Array(snapshot).map { |el| identity_tuple(el) }.compact.sort
        Digest::SHA1.hexdigest(keys.join("\n"))[0, 16]
      end

      # Returns { added: [...], removed: [...] } of element selectors that
      # differ between two snapshots. Empty arrays mean structurally identical.
      def compare(prev, current)
        prev_set    = element_set(prev)
        current_set = element_set(current)
        {
          added: (current_set - prev_set).sort,
          removed: (prev_set - current_set).sort
        }
      end

      def identity_tuple(entry)
        return nil unless entry.is_a?(Hash)

        sel = entry[:selector] || entry["selector"]
        role = entry[:role] || entry["role"]
        tag = entry[:tag] || entry["tag"]
        return nil unless sel

        "#{sel}|#{role}|#{tag}"
      end

      def element_set(snapshot)
        Array(snapshot).map { |entry| entry[:selector] || entry["selector"] }.compact
      end
    end
  end
end

# frozen_string_literal: true

require "digest"

module Browserctl
  module Snapshot
    # Derives a stable element ref from semantic + structural signals.
    #
    # The same DOM element should produce the same ref across two snapshots
    # of the same page. Inputs to the hash are:
    #   - role (explicit @role, else implicit ARIA role from tag)
    #   - accessible name (aria-label || text || placeholder || alt)
    #   - tag
    #   - parent path (chain of ancestor tag names up to <html>)
    #
    # Collisions within a single snapshot are disambiguated by the caller via
    # `disambiguate(ref, taken)` — the deriver itself is pure.
    class RefDeriver
      IMPLICIT_ROLE = {
        "a" => "link", "button" => "button", "input" => "textbox",
        "select" => "combobox", "textarea" => "textbox"
      }.freeze

      HASH_LEN = 7

      def derive(node)
        signal = [role(node), accessible_name(node), node.name, parent_path(node)].join("|")
        "e#{Digest::SHA256.hexdigest(signal)[0, HASH_LEN]}"
      end

      # Given a candidate ref and a set of already-taken refs in the current
      # snapshot, return a unique ref. Adds `-2`, `-3`, ... as needed.
      def disambiguate(ref, taken)
        return ref unless taken.include?(ref)

        n = 2
        n += 1 while taken.include?("#{ref}-#{n}")
        "#{ref}-#{n}"
      end

      private

      def role(node)
        explicit = node["role"]
        return explicit if explicit && !explicit.empty?

        IMPLICIT_ROLE[node.name] || node.name
      end

      def accessible_name(node)
        %w[aria-label placeholder alt title].each do |attr|
          v = node[attr]
          return v.strip if v && !v.strip.empty?
        end
        text = node.text.to_s.strip
        text.empty? ? "" : text.slice(0, 80)
      end

      def parent_path(node)
        parts = []
        cur = node.parent
        while cur&.respond_to?(:name) && cur.name != "html" && cur.name != "document"
          parts.unshift(cur.name)
          cur = cur.parent
        end
        parts.join(">")
      end
    end
  end
end

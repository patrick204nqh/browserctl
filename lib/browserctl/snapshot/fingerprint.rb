# frozen_string_literal: true

require "browserctl/snapshot/ref"

module Browserctl
  module Snapshot
    # Builds a per-element fingerprint that survives small DOM changes.
    #
    # The fingerprint is later used by the replay layer to rematch an
    # element when its recorded selector no longer resolves: score the
    # candidate elements in the new DOM against the recorded fingerprint
    # and pick the best match above a threshold.
    #
    # Shape:
    #   {
    #     text:      <accessible name>,
    #     role:      <ARIA role, explicit or implicit>,
    #     neighbors: [<short text of nearby siblings>, ...],
    #     position:  { index: <int>, depth: <int> }
    #   }
    class Fingerprint
      NEIGHBOR_RADIUS = 2 # siblings to capture on each side
      NEIGHBOR_TEXT_LEN = 40

      def initialize(ref_deriver: RefDeriver.new)
        @ref_deriver = ref_deriver
      end

      def build(node)
        {
          text: accessible_name(node),
          role: role(node),
          neighbors: neighbors(node),
          position: position(node)
        }
      end

      private

      def role(node)
        explicit = node["role"]
        return explicit if explicit && !explicit.empty?

        RefDeriver::IMPLICIT_ROLE[node.name] || node.name
      end

      def accessible_name(node)
        %w[aria-label placeholder alt title].each do |attr|
          v = node[attr]
          return v.strip if v && !v.strip.empty?
        end
        node.text.to_s.strip.slice(0, 80)
      end

      def neighbors(node)
        parent = node.parent
        return [] unless parent.respond_to?(:children)

        idx = parent.children.to_a.index(node) || 0
        window = parent.children.to_a[[idx - NEIGHBOR_RADIUS, 0].max...(idx + NEIGHBOR_RADIUS + 1)] || []
        window
          .reject { |c| c == node || !c.respond_to?(:name) }
          .map { |c| neighbor_signal(c) }
          .reject(&:empty?)
      end

      def neighbor_signal(node)
        text = node.text.to_s.strip.gsub(/\s+/, " ").slice(0, NEIGHBOR_TEXT_LEN)
        text.empty? ? "" : "#{node.name}:#{text}"
      end

      def position(node)
        idx = node.parent.respond_to?(:children) ? (node.parent.children.to_a.index(node) || 0) : 0
        { index: idx, depth: depth(node) }
      end

      def depth(node)
        d = 0
        cur = node.parent
        while cur.respond_to?(:name) && cur.name != "document"
          d += 1
          cur = cur.parent
        end
        d
      end
    end
  end
end

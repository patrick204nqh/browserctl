# frozen_string_literal: true

require "browserctl/snapshot/ref"
require "browserctl/snapshot/fingerprint"

module Browserctl
  module Snapshot
    # Stage 2 of the snapshot pipeline.
    #
    # Takes the list of interactable nodes from Extractor and produces
    # element entries with stable refs, semantic metadata, a CSS selector
    # path, and a fingerprint. Each entry is a plain Hash.
    class Annotator
      ATTRS = %w[type name placeholder href aria-label role].freeze

      def initialize(ref_deriver: RefDeriver.new, fingerprint: Fingerprint.new)
        @ref_deriver = ref_deriver
        @fingerprint = fingerprint
      end

      def call(nodes)
        taken = {}
        nodes.map do |node|
          ref = @ref_deriver.disambiguate(@ref_deriver.derive(node), taken)
          taken[ref] = true
          entry(node, ref)
        end
      end

      private

      def entry(node, ref)
        {
          ref: ref,
          tag: node.name,
          text: node.text.strip.slice(0, 80),
          selector: css_path(node),
          attrs: attrs(node),
          fingerprint: @fingerprint.build(node)
        }
      end

      def attrs(node)
        node.attributes.transform_values(&:value).slice(*ATTRS)
      end

      def css_path(node)
        ancestors_until_html(node).map { |n| segment(n) }.join(" > ")
      end

      def ancestors_until_html(node)
        [].tap do |acc|
          while node && node.name != "html"
            acc.unshift(node)
            node = node.parent
          end
        end
      end

      def segment(node)
        node.name + id_fragment(node) + class_fragment(node)
      end

      def id_fragment(node)
        (id = node["id"]) && !id.empty? ? "##{id}" : ""
      end

      def class_fragment(node)
        return "" if node["id"] && !node["id"].empty?

        (klass = node["class"]&.split&.first) ? ".#{klass}" : ""
      end
    end
  end
end

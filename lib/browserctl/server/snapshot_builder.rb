# frozen_string_literal: true

require "nokogiri"
require "browserctl/snapshot/ref"

module Browserctl
  class SnapshotBuilder
    INTERACTABLE = %w[a button input select textarea
                      [role=button] [role=link] [role=menuitem]].freeze
    ATTRS        = %w[type name placeholder href aria-label role].freeze

    def initialize(ref_deriver: Snapshot::RefDeriver.new)
      @ref_deriver = ref_deriver
    end

    def call(page)
      doc = Nokogiri::HTML(page.body)
      taken = {}
      doc.css(INTERACTABLE.join(",")).map do |el|
        ref = @ref_deriver.disambiguate(@ref_deriver.derive(el), taken)
        taken[ref] = true
        element_entry(el, ref)
      end
    end

    private

    def element_entry(elem, ref)
      { ref: ref, tag: elem.name, text: elem.text.strip.slice(0, 80),
        selector: css_path(elem), attrs: element_attrs(elem) }
    end

    def element_attrs(elem)
      elem.attributes.transform_values(&:value).slice(*ATTRS)
    end

    def css_path(node)
      ancestors_until_html(node).map { |n| path_segment(n) }.join(" > ")
    end

    def ancestors_until_html(node)
      [].tap do |acc|
        while node && node.name != "html"
          acc.unshift(node)
          node = node.parent
        end
      end
    end

    def path_segment(node)
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

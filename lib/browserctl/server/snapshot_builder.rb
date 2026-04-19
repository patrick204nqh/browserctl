# frozen_string_literal: true

require "nokogiri"

module Browserctl
  class SnapshotBuilder
    INTERACTABLE = %w[a button input select textarea
                      [role=button] [role=link] [role=menuitem]].freeze
    ATTRS        = %w[type name placeholder href aria-label role].freeze

    def call(page)
      doc = Nokogiri::HTML(page.body)
      ref = 0
      doc.css(INTERACTABLE.join(",")).map { |el| element_entry(el, ref += 1) }
    end

    private

    def element_entry(el, ref)
      { ref: "e#{ref}", tag: el.name, text: el.text.strip.slice(0, 80),
        selector: css_path(el), attrs: element_attrs(el) }
    end

    def element_attrs(el)
      el.attributes.transform_values(&:value).slice(*ATTRS)
    end

    def css_path(node)
      ancestors_until_html(node).map { |n| path_segment(n) }.join(" > ")
    end

    def ancestors_until_html(node)
      [].tap { |acc| acc.unshift(node) && (node = node.parent) while node&.name != "html" }
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

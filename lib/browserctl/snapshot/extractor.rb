# frozen_string_literal: true

require "nokogiri"

module Browserctl
  module Snapshot
    # Stage 1 of the snapshot pipeline.
    #
    # Parses raw HTML and returns the set of interactable Nokogiri nodes
    # that the rest of the pipeline will annotate. This stage knows nothing
    # about refs, fingerprints, or wire format.
    class Extractor
      INTERACTABLE = %w[a button input select textarea
                        [role=button] [role=link] [role=menuitem]].freeze

      def call(html)
        Nokogiri::HTML(html).css(INTERACTABLE.join(",")).to_a
      end
    end
  end
end

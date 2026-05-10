# frozen_string_literal: true

require "browserctl/snapshot/extractor"
require "browserctl/snapshot/annotator"
require "browserctl/snapshot/serializer"

module Browserctl
  # Orchestrates the snapshot pipeline:
  #
  #   page.body  ──Extractor──▶  [nodes]
  #              ──Annotator──▶  [entries with ref + fingerprint]
  #              ──Serializer─▶  wire-shape array
  #
  # Each stage is independently testable. Inject alternates via the keyword
  # args for tests that want to isolate one stage.
  class SnapshotBuilder
    def initialize(extractor: Snapshot::Extractor.new,
                   annotator: Snapshot::Annotator.new,
                   serializer: Snapshot::Serializer.new)
      @extractor = extractor
      @annotator = annotator
      @serializer = serializer
    end

    def call(page)
      nodes = @extractor.call(page.body)
      entries = @annotator.call(nodes)
      @serializer.call(entries)
    end
  end
end

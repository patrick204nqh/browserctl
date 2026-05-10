# frozen_string_literal: true

module Browserctl
  module Snapshot
    # Stage 3 of the snapshot pipeline.
    #
    # Right now this is the identity function — annotated entries are
    # already in the wire shape clients expect. It exists as a seam so
    # later milestones can canonicalize, redact, or compress without
    # touching extraction or annotation.
    class Serializer
      def call(entries)
        entries
      end
    end
  end
end

# frozen_string_literal: true

module Browserctl
  class PageSession
    attr_reader :page, :mutex
    attr_accessor :ref_registry, :prev_snapshot

    def initialize(page)
      @page          = page
      @mutex         = Mutex.new
      @ref_registry  = {}
      @prev_snapshot = nil
    end
  end
end

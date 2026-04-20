# frozen_string_literal: true

module Browserctl
  class PageSession
    attr_reader :page, :mutex, :pause_cv
    attr_accessor :ref_registry, :prev_snapshot

    def initialize(page)
      @page          = page
      @mutex         = Mutex.new
      @pause_cv      = ConditionVariable.new
      @ref_registry  = {}
      @prev_snapshot = nil
      @paused        = false
    end

    def paused? = @paused
    def pause!  = (@paused = true)
    def resume! = (@paused = false)
  end
end

# frozen_string_literal: true

require_relative "../driver/page_driver"

module Browserctl
  class PageSession
    attr_reader :driver, :mutex, :pause_cv
    attr_accessor :ref_registry, :prev_snapshot, :fingerprint_index, :snapshot_id

    # @param driver [Browserctl::Driver::PageDriver] a PageDriver
    #   implementation (or any duck-typed equivalent in tests). Raw Ferrum
    #   pages are no longer accepted — wrap with
    #   {Browserctl::Driver::FerrumPageDriver} at the call site.
    def initialize(driver)
      @driver            = driver
      @mutex             = Mutex.new
      @pause_cv          = ConditionVariable.new
      @ref_registry      = {}
      @fingerprint_index = {}
      @snapshot_id       = nil
      @prev_snapshot     = nil
      @paused            = false
    end

    def paused? = @paused
    def pause!  = (@paused = true)
    def resume! = (@paused = false)
  end
end

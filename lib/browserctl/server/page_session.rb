# frozen_string_literal: true

require_relative "../driver/ferrum_page_driver"

module Browserctl
  class PageSession
    attr_reader :driver, :mutex, :pause_cv
    attr_accessor :ref_registry, :prev_snapshot, :fingerprint_index, :snapshot_id

    # @param page_or_driver [Browserctl::Driver::PageDriver, Object] either a
    #   PageDriver (preferred) or a raw Ferrum/CDP page (auto-wrapped in
    #   {Browserctl::Driver::FerrumPageDriver} for back-compat with callers
    #   that still construct sessions from a raw page).
    def initialize(page_or_driver)
      @driver = if page_or_driver.is_a?(Browserctl::Driver::PageDriver)
                  page_or_driver
                else
                  Browserctl::Driver::FerrumPageDriver.new(page_or_driver)
                end
      @mutex             = Mutex.new
      @pause_cv          = ConditionVariable.new
      @ref_registry      = {}
      @fingerprint_index = {}
      @snapshot_id       = nil
      @prev_snapshot     = nil
      @paused            = false
    end

    # Back-compat accessor. New handler code calls {#driver} directly; this
    # returns the underlying Ferrum/CDP page for legacy callers (the CDP
    # driver's `devtools_info`, the page-lifecycle close path, and a unit
    # spec).
    def page
      @driver.respond_to?(:raw_page) ? @driver.raw_page : @driver
    end

    def paused? = @paused
    def pause!  = (@paused = true)
    def resume! = (@paused = false)
  end
end

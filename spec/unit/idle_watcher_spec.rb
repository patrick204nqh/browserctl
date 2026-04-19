# frozen_string_literal: true

require "spec_helper"
require "browserctl/server/idle_watcher"

RSpec.describe Browserctl::IdleWatcher do
  describe "#idle?" do
    it "returns true when last_used exceeds IDLE_TTL" do
      fn      = -> { Time.now - Browserctl::IDLE_TTL - 1 }
      watcher = described_class.new(fn)
      expect(watcher.send(:idle?)).to be true
    end

    it "returns false when recently used" do
      fn      = -> { Time.now }
      watcher = described_class.new(fn)
      expect(watcher.send(:idle?)).to be false
    end
  end
end

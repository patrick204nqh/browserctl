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

  describe "#watch" do
    it "calls shutdown when idle" do
      fn      = -> { Time.now - Browserctl::IDLE_TTL - 1 }
      watcher = described_class.new(fn)
      server  = double("server")
      allow(watcher).to receive(:sleep)
      allow(watcher).to receive(:shutdown)
      allow(watcher).to receive(:idle?).and_return(false, true)
      watcher.watch(server)
      expect(watcher).to have_received(:shutdown).with(server).once
    end
  end

  describe "#shutdown" do
    it "closes server and sends SIGINT" do
      fn      = -> { Time.now }
      watcher = described_class.new(fn)
      server  = double("server")
      allow(server).to receive(:close)
      allow(Process).to receive(:kill)
      watcher.send(:shutdown, server)
      expect(server).to have_received(:close)
      expect(Process).to have_received(:kill).with("INT", Process.pid)
    end
  end
end

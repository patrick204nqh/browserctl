# frozen_string_literal: true

require "spec_helper"
require "browserctl/server/page_session"

RSpec.describe Browserctl::PageSession do
  let(:page) { double("Ferrum::Page") }
  subject(:session) { described_class.new(page) }

  it "holds the page" do
    expect(session.page).to eq(page)
  end

  it "starts with an empty ref_registry" do
    expect(session.ref_registry).to eq({})
  end

  it "starts with nil prev_snapshot" do
    expect(session.prev_snapshot).to be_nil
  end

  it "has its own Mutex" do
    expect(session.mutex).to be_a(Mutex)
  end

  it "allows ref_registry to be updated" do
    session.ref_registry = { "e1" => "input#email" }
    expect(session.ref_registry["e1"]).to eq("input#email")
  end

  it "allows prev_snapshot to be updated" do
    snapshot = [{ ref: "e1", tag: "input" }]
    session.prev_snapshot = snapshot
    expect(session.prev_snapshot).to eq(snapshot)
  end

  it "has a separate mutex per instance" do
    other = described_class.new(double("page2"))
    expect(session.mutex).not_to equal(other.mutex)
  end

  describe "pause/resume" do
    it "starts unpaused" do
      expect(session.paused?).to be false
    end

    it "pause! marks the session as paused" do
      session.pause!
      expect(session.paused?).to be true
    end

    it "resume! clears the paused flag" do
      session.pause!
      session.resume!
      expect(session.paused?).to be false
    end

    it "exposes a ConditionVariable" do
      expect(session.pause_cv).to be_a(ConditionVariable)
    end

    it "has a separate pause_cv per instance" do
      other = described_class.new(double("page2"))
      expect(session.pause_cv).not_to equal(other.pause_cv)
    end
  end
end

# frozen_string_literal: true

require "spec_helper"
require "browserctl/server/snapshot_builder"

FIXTURES_DIR = File.expand_path("../fixtures/snapshots", __dir__)

RSpec.describe "Snapshot determinism" do
  def page(name) = double("page", body: File.read(File.join(FIXTURES_DIR, name)))

  let(:builder) { Browserctl::SnapshotBuilder.new }

  describe "stable refs across calls" do
    it "produces identical refs when snapshotting the same page twice" do
      first  = builder.call(page("login_form.html"))
      second = builder.call(page("login_form.html"))
      expect(second.map { |e| e[:ref] }).to eq(first.map { |e| e[:ref] })
    end

    it "every entry has the expected wire-shape keys" do
      entry = builder.call(page("login_form.html")).first
      expect(entry.keys).to include(:ref, :tag, :text, :selector, :attrs, :fingerprint)
    end

    it "all refs are unique within a snapshot" do
      refs = builder.call(page("login_form.html")).map { |e| e[:ref] }
      expect(refs.uniq.size).to eq(refs.size)
    end
  end

  describe "fingerprint survives structural drift" do
    it "matches Sign-in button across class-only mutations" do
      base    = builder.call(page("login_form.html"))
      mutated = builder.call(page("login_form_mutated.html"))

      base_btn    = base.find    { |e| e[:tag] == "button" }
      mutated_btn = mutated.find { |e| e[:tag] == "button" }

      expect(mutated_btn[:fingerprint]).to eq(base_btn[:fingerprint])
    end

    it "matches each labelled input across class-only mutations" do
      base    = builder.call(page("login_form.html")).select { |e| e[:tag] == "input" }
      mutated = builder.call(page("login_form_mutated.html")).select { |e| e[:tag] == "input" }

      base.zip(mutated).each do |b, m|
        expect(m[:fingerprint][:text]).to eq(b[:fingerprint][:text])
        expect(m[:fingerprint][:role]).to eq(b[:fingerprint][:role])
      end
    end

    it "ref and fingerprint are independent of class attributes" do
      base    = builder.call(page("login_form.html")).map { |e| [e[:ref], e[:fingerprint]] }
      mutated = builder.call(page("login_form_mutated.html")).map { |e| [e[:ref], e[:fingerprint]] }
      expect(mutated).to eq(base)
    end
  end
end

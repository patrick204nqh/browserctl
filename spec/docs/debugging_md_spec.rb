# frozen_string_literal: true

require "spec_helper"

# Smoke test: guard the debugging guide against link rot and section drift.
# This is intentionally narrow — it asserts the doc exists and that the
# section headings the README/CHANGELOG point at are still present.
RSpec.describe "docs/guides/debugging.md" do
  let(:path) { File.expand_path("../../docs/guides/debugging.md", __dir__) }
  let(:body) { File.read(path) }

  it "exists" do
    expect(File).to exist(path)
  end

  it "covers the trace -> crash -> issue loop" do
    [
      "## When something doesn't work",
      "## Reading a trace",
      "## Redaction (it's on by default)",
      "## Crash reports",
      "## Filing a good issue"
    ].each do |heading|
      expect(body).to include(heading)
    end
  end

  it "is linked from the README" do
    readme = File.read(File.expand_path("../../README.md", __dir__))
    expect(readme).to include("docs/guides/debugging.md")
  end
end

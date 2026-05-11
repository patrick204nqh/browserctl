# frozen_string_literal: true

require "spec_helper"
require "browserctl/trace/renderer"
require "browserctl/redactor"
require "stringio"

RSpec.describe Browserctl::Trace::Renderer do
  let(:out) { StringIO.new }

  let(:records) do
    [
      { "ts" => "2026-05-10T06:21:48.500Z", "level" => "INFO",
        "component" => "daemon", "event" => "ready", "port" => 1234 },
      { "ts" => "2026-05-10T06:21:50.000Z", "level" => "ERROR",
        "component" => "daemon", "msg" => "kaboom" }
    ]
  end

  it "renders a fixed event sequence as a timeline" do
    described_class.new(io: out, color: false).render(records)
    lines = out.string.lines.map(&:rstrip)
    expect(lines.length).to eq(2)
    expect(lines[0]).to include("06:21:48.500", "INFO", "daemon", "ready", "port=1234")
    expect(lines[1]).to include("06:21:50.000", "!", "ERROR", "kaboom")
  end

  it "omits ANSI colour codes when color: false" do
    described_class.new(io: out, color: false).render(records)
    expect(out.string).not_to include("\e[")
  end

  it "emits ANSI colour codes when color: true" do
    described_class.new(io: out, color: true).render(records)
    expect(out.string).to include("\e[")
  end

  it "defaults color to TTY-detection of the target IO" do
    allow(out).to receive_messages(tty?: false)
    described_class.new(io: out).render(records)
    expect(out.string).not_to include("\e[")
  end

  it "applies the injected redactor to formatted lines" do
    redactor = Browserctl::Redactor.new(secrets: ["kaboom"])
    described_class.new(io: out, color: false, redactor: redactor).render(records)
    expect(out.string).not_to include("kaboom")
    expect(out.string).to include("[REDACTED]")
  end

  it "renders a fallback timestamp for malformed ts values" do
    described_class.new(io: out, color: false).render([{ "ts" => "garbage", "level" => "INFO" }])
    expect(out.string).to include("??:??:??.???")
  end

  it "categorises snapshot, network, and event records with distinct icons" do
    snap = { "ts" => "2026-05-10T06:00:00.000Z", "snapshot" => "snap1", "component" => "cli" }
    net  = { "ts" => "2026-05-10T06:00:01.000Z", "url" => "https://example.com", "component" => "cli" }
    ev   = { "ts" => "2026-05-10T06:00:02.000Z", "event" => "click", "component" => "cli" }

    described_class.new(io: out, color: false).render([snap, net, ev])
    lines = out.string.lines.map(&:rstrip)
    expect(lines[0]).to match(/06:00:00\.000\s+S\s/)
    expect(lines[1]).to match(/06:00:01\.000\s+N\s/)
    expect(lines[2]).to match(/06:00:02\.000\s+\.\s/)
  end
end

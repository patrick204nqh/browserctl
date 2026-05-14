# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "browserctl/commands/deprecation_notice"
require "browserctl/commands/output_format"

RSpec.describe Browserctl::Commands::DeprecationNotice do
  before do
    described_class.reset!
    Browserctl::Commands::OutputFormat.reset!
  end

  after do
    described_class.reset!
    Browserctl::Commands::OutputFormat.reset!
  end

  it "emits a one-line warning to stderr" do
    io = StringIO.new
    described_class.emit("cookie set", "data set --scope cookies", io: io)
    expect(io.string).to eq(
      "warning: 'cookie set' is deprecated; use 'data set --scope cookies'. Removed at 1.0.\n"
    )
  end

  it "emits the warning exactly once per process even across multiple calls" do
    io = StringIO.new
    described_class.emit("cookie set", "data set --scope cookies", io: io)
    described_class.emit("storage get", "data get --scope localStorage", io: io)
    described_class.emit("cookie list", "data list --scope cookies", io: io)
    expect(io.string.lines.length).to eq(1)
  end

  it "is suppressed under --output json" do
    Browserctl::Commands::OutputFormat.current = Browserctl::Commands::OutputFormat.from("json")
    io = StringIO.new
    described_class.emit("cookie set", "data set --scope cookies", io: io)
    expect(io.string).to eq("")
  end

  it "still emits under --output text" do
    Browserctl::Commands::OutputFormat.current = Browserctl::Commands::OutputFormat.from("text")
    io = StringIO.new
    described_class.emit("cookie set", "data set --scope cookies", io: io)
    expect(io.string).to include("warning:")
  end

  it "still emits under --output silent (silent only affects stdout)" do
    Browserctl::Commands::OutputFormat.current = Browserctl::Commands::OutputFormat.from("silent")
    io = StringIO.new
    described_class.emit("cookie set", "data set --scope cookies", io: io)
    expect(io.string).to include("warning:")
  end
end

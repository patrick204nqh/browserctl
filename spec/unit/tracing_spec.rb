# frozen_string_literal: true

require "spec_helper"
require "browserctl/tracing"
require "browserctl/server/command_dispatcher"
require "browserctl/server/page_session"

# Test double that records every span as a hash so tests can introspect.
class TracingSpecRecorder
  attr_reader :spans

  def initialize
    @spans = []
  end

  def start_span(name, attributes: {})
    span = { name: name, attributes: attributes.dup, status: nil, end_attrs: nil }
    @spans << span
    span
  end

  def end_span(span, status:, attributes: {})
    return if span.nil?

    span[:status] = status
    span[:end_attrs] = attributes
  end
end

RSpec.describe Browserctl::Tracing do
  # Restore default backend after each test so nothing leaks.
  after { described_class.backend = nil }

  describe "default backend" do
    it "is a NoopBackend" do
      described_class.backend = nil
      expect(described_class.backend).to be_a(Browserctl::Tracing::NoopBackend)
    end

    it "in_span returns the block result" do
      expect(described_class.in_span("x", attributes: {}) { 42 }).to eq(42)
    end

    it "in_span re-raises exceptions" do
      expect { described_class.in_span("x", attributes: {}) { raise "boom" } }
        .to raise_error("boom")
    end
  end

  describe "with a recorder backend" do
    let(:recorder) { TracingSpecRecorder.new }

    before { described_class.backend = recorder }

    it "records one span per command with command:, page:, duration_ms: attributes" do
      driver = instance_double("Driver")
      page = double("page")
      allow(driver).to receive(:create_page).and_return(page)
      dispatcher = Browserctl::CommandDispatcher.new({}, driver)

      dispatcher.dispatch({ cmd: "page_open", name: "home" })

      expect(recorder.spans.length).to eq(1)
      span = recorder.spans.first
      expect(span[:name]).to eq("command.page_open")
      expect(span[:attributes][:command]).to eq("page_open")
      expect(span[:attributes][:page]).to eq("home")
      expect(span[:status]).to eq(:ok)
      expect(span[:end_attrs][:duration_ms]).to be_a(Numeric)
      expect(span[:end_attrs][:duration_ms]).to be >= 0
    end

    it "marks span :error when the handler raises" do
      expect do
        described_class.in_span("command.boom", attributes: { command: "boom" }) do
          raise "kaboom"
        end
      end.to raise_error("kaboom")

      span = recorder.spans.first
      expect(span[:status]).to eq(:error)
      expect(span[:end_attrs][:duration_ms]).to be_a(Numeric)
    end
  end
end

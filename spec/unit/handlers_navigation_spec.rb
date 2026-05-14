# frozen_string_literal: true

require "spec_helper"
require "browserctl/server/command_dispatcher"

# Targets the narrowed rescue in
# Browserctl::CommandDispatcher::Handlers::Navigation#capture_post_snapshot_digest.
RSpec.describe Browserctl::CommandDispatcher::Handlers::Navigation do
  # Minimal harness exposing the private method without booting the full
  # dispatcher (which would require a live Ferrum browser).
  let(:harness_class) do
    Class.new do
      include Browserctl::CommandDispatcher::Handlers::Navigation

      def initialize(snapshot_builder)
        @snapshot_builder = snapshot_builder
      end

      public :capture_post_snapshot_digest
    end
  end

  let(:session) { instance_double("Browserctl::PageSession", driver: :fake_driver) }

  context "expected exceptions are swallowed and logged at debug" do
    [
      JSON::ParserError.new("bad json"),
      Timeout::Error.new("snapshot timeout"),
      Browserctl::Error.new("typed failure")
    ].each do |err|
      it "returns nil and logs at debug when snapshot raises #{err.class}" do
        builder = ->(_driver) { raise err }
        harness = harness_class.new(builder)
        debug_messages = []
        allow(Browserctl).to receive(:logger).and_return(
          instance_double("Logger").tap do |l|
            allow(l).to receive(:debug) { |msg| debug_messages << msg }
          end
        )

        expect(harness.capture_post_snapshot_digest(session)).to be_nil
        expect(debug_messages.last).to include("post-snapshot digest skipped", err.class.to_s)
      end
    end
  end

  it "propagates unexpected exceptions (rescue is no longer too wide)" do
    builder = ->(_driver) { raise "unexpected" }
    harness = harness_class.new(builder)

    expect { harness.capture_post_snapshot_digest(session) }
      .to raise_error(RuntimeError, "unexpected")
  end

  it "propagates ArgumentError (proves StandardError-wide rescue is gone)" do
    builder = ->(_driver) { raise ArgumentError, "bad arg" }
    harness = harness_class.new(builder)

    expect { harness.capture_post_snapshot_digest(session) }
      .to raise_error(ArgumentError)
  end
end

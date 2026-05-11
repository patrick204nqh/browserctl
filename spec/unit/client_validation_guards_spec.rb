# frozen_string_literal: true

require "spec_helper"
require "browserctl/client"
require "browserctl/errors"

# Unit coverage for the five "provide selector or ref" guards in
# Browserctl::Client. The guards raise Browserctl::Error with the canonical
# INVALID_SELECTOR_REF code so agents can branch on the structured payload
# instead of string-matching ArgumentError prose.
#
# These guards execute before any UNIX-socket connection, so we can drive
# them with a Client pointed at a non-existent socket path — the guard
# raises before `call` ever runs.
RSpec.describe Browserctl::Client, "selector-or-ref guards" do
  subject(:client) { described_class.new("/tmp/browserctl-nonexistent-#{Process.pid}.sock") }

  # method_name, args (positional + kwargs as a proc, since fill/upload/select
  # take more positional args)
  cases = [
    [:click,  ->(c, name) { c.click(name) }],
    [:fill,   ->(c, name) { c.fill(name) }],
    [:hover,  ->(c, name) { c.hover(name) }],
    [:upload, ->(c, name) { c.upload(name) }],
    [:select, ->(c, name) { c.select(name) }]
  ]

  cases.each do |method_name, invoker|
    describe "##{method_name}" do
      it "raises Browserctl::Error with INVALID_SELECTOR_REF when neither selector nor ref is provided" do
        expect { invoker.call(client, "somepage") }
          .to raise_error(Browserctl::Error) do |err|
            expect(err.code).to eq(Browserctl::Error::Codes::INVALID_SELECTOR_REF)
            expect(err.message).to include("provide selector or ref")
            expect(err.context).to include(method: method_name, name: "somepage")
          end
      end

      it "is not an ArgumentError" do
        expect { invoker.call(client, "somepage") }.not_to raise_error(ArgumentError)
      end
    end
  end
end

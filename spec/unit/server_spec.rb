# frozen_string_literal: true

require "spec_helper"
require "timeout"
require "browserctl/server"

RSpec.describe Browserctl::Server do
  describe "#quietly (private)" do
    subject(:server) { described_class.allocate }

    it "swallows StandardError" do
      expect { server.send(:quietly) { raise "boom" } }.not_to raise_error
    end

    it "swallows Timeout::Error" do
      expect { server.send(:quietly) { raise Timeout::Error } }.not_to raise_error
    end
  end
end

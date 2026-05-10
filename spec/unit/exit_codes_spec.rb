# frozen_string_literal: true

require "English"
require "spec_helper"
require "browserctl/errors"

RSpec.describe Browserctl::Error::ExitCodes do
  describe "stable integer constants" do
    it "pins each named status to its v0.12 wire-stable integer" do
      {
        OK: 0,
        GENERIC: 1,
        DRIFT: 2,
        AUTH_REQUIRED: 3,
        DAEMON_UNREACHABLE: 4,
        PROTOCOL_MISMATCH: 5,
        SELECTOR_NOT_FOUND: 6,
        STATE_EXPIRED: 7
      }.each do |const, value|
        expect(described_class.const_get(const)).to eq(value)
      end
    end
  end

  describe ".for" do
    it "maps each canonical Codes::* with a dedicated exit code" do
      {
        Browserctl::Error::Codes::AUTH_REQUIRED => 3,
        Browserctl::Error::Codes::DAEMON_UNREACHABLE => 4,
        Browserctl::Error::Codes::PROTOCOL_MISMATCH => 5,
        Browserctl::Error::Codes::SELECTOR_NOT_FOUND => 6,
        Browserctl::Error::Codes::STATE_EXPIRED => 7
      }.each do |code, expected|
        expect(described_class.for(code)).to eq(expected)
      end
    end

    it "returns GENERIC (1) for nil" do
      expect(described_class.for(nil)).to eq(1)
    end

    it "returns GENERIC (1) for an unknown string" do
      expect(described_class.for("UNKNOWN")).to eq(1)
      expect(described_class.for("not_a_code")).to eq(1)
      expect(described_class.for("")).to eq(1)
    end

    it "returns GENERIC (1) for codes that exist in the enum but have no dedicated exit slot" do
      expect(described_class.for(Browserctl::Error::Codes::GENERIC)).to eq(1)
      expect(described_class.for(Browserctl::Error::Codes::DOMAIN_NOT_ALLOWED)).to eq(1)
      expect(described_class.for(Browserctl::Error::Codes::KEY_NOT_FOUND)).to eq(1)
      expect(described_class.for(Browserctl::Error::Codes::SECRET_RESOLUTION_FAILED)).to eq(1)
    end

    it "DRIFT (2) is reserved — no canonical Codes::* maps to it yet" do
      mapped = Browserctl::Error::Codes.all.map { |c| described_class.for(c) }
      expect(mapped).not_to include(described_class::DRIFT)
    end

    it "never raises for arbitrary input" do
      [nil, "", "x", :sym, 123].each do |bad|
        expect { described_class.for(bad) }.not_to raise_error
      end
    end
  end

  describe "CLI top-level rescue integration" do
    let(:bin) { File.expand_path("../../bin/browserctl", __dir__) }

    # Drives the CLI binary against a non-existent daemon socket. The
    # client raises Browserctl::DaemonUnavailableError (code:
    # DAEMON_UNREACHABLE), which the new top-level rescue must map to
    # exit status 4 — the strongest end-to-end assertion that the map is
    # wired into the binary's escape path.
    it "maps a typed DAEMON_UNREACHABLE error to exit code 4" do
      Dir.mktmpdir do |home|
        out = `BROWSERCTL_HOME=#{home} HOME=#{home} #{bin} state load any-name 2>&1`
        status = $CHILD_STATUS.exitstatus
        expect(status).to eq(4), "expected exit 4, got #{status}; output:\n#{out}"
        expect(out).to include("DAEMON_UNREACHABLE")
      end
    end
  end
end

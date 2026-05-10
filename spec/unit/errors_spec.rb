# frozen_string_literal: true

require "spec_helper"
require "browserctl/errors"

RSpec.describe Browserctl::Error do
  it "has a code" do
    err = described_class.new("something broke", code: "generic_error")
    expect(err.code).to eq("generic_error")
    expect(err.message).to eq("something broke")
  end

  it "defaults to its class default_code" do
    err = Browserctl::PageNotFound.new("no page named 'main'")
    expect(err.code).to eq("page_not_found")
    expect(err.message).to eq("no page named 'main'")
  end
end

RSpec.describe Browserctl::SelectorNotFound do
  it "has code SELECTOR_NOT_FOUND" do
    expect(described_class.new("x").code).to eq("SELECTOR_NOT_FOUND")
    expect(described_class.new("x").code).to eq(Browserctl::Error::Codes::SELECTOR_NOT_FOUND)
  end
end

RSpec.describe Browserctl::RefNotFound do
  it "has code ref_not_found" do
    expect(described_class.new("x").code).to eq("ref_not_found")
  end
end

RSpec.describe Browserctl::PathNotAllowed do
  it "has code path_not_allowed" do
    expect(described_class.new("x").code).to eq("path_not_allowed")
  end
end

RSpec.describe Browserctl::DomainNotAllowed do
  it "has code domain_not_allowed" do
    expect(described_class.new("x").code).to eq("domain_not_allowed")
  end
end

RSpec.describe Browserctl::TimeoutError do
  it "has code timeout" do
    expect(described_class.new("x").code).to eq("timeout")
  end
end

RSpec.describe Browserctl::KeyNotFound do
  it "has code key_not_found" do
    expect(described_class.new("x").code).to eq("key_not_found")
  end
end

RSpec.describe Browserctl::DaemonUnavailableError do
  it "has code DAEMON_UNREACHABLE" do
    expect(described_class.new("x").code).to eq("DAEMON_UNREACHABLE")
    expect(described_class.new("x").code).to eq(Browserctl::Error::Codes::DAEMON_UNREACHABLE)
  end
end

RSpec.describe Browserctl::SecretResolverError do
  it "has code SECRET_RESOLUTION_FAILED" do
    expect(described_class.new("x").code).to eq("SECRET_RESOLUTION_FAILED")
    expect(described_class.new("x").code).to eq(Browserctl::Error::Codes::SECRET_RESOLUTION_FAILED)
  end
end

RSpec.describe Browserctl::ProtocolMismatch do
  it "has code PROTOCOL_MISMATCH" do
    expect(described_class.new("x").code).to eq("PROTOCOL_MISMATCH")
    expect(described_class.new("x").code).to eq(Browserctl::Error::Codes::PROTOCOL_MISMATCH)
  end
end

RSpec.describe "daemon ping JSON error path" do
  require "browserctl/commands/daemon"
  require "stringio"

  it "emits JSON with ok:false and daemon:offline and exits 1 when daemon is unavailable" do
    client = instance_double(Browserctl::Client)
    allow(client).to receive(:ping).and_raise(Browserctl::DaemonUnavailableError, "browserd is not running")

    original = $stdout
    $stdout = StringIO.new
    begin
      expect do
        Browserctl::Commands::Daemon.run(client, ["ping"])
      end.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      output = $stdout.string
    ensure
      $stdout = original
    end

    parsed = JSON.parse(output)
    expect(parsed["ok"]).to be false
    expect(parsed["daemon"]).to eq("offline")
  end
end

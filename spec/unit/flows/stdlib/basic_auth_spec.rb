# frozen_string_literal: true

require "spec_helper"
require "browserctl/flows/stdlib/basic_auth"

RSpec.describe "stdlib flow: basic_auth" do
  let(:page) { instance_double(Browserctl::PageProxy) }

  before do
    Browserctl.flow_registry_reset!
    load File.expand_path("../../../../lib/browserctl/flows/stdlib/basic_auth.rb", __dir__)
  end
  after { Browserctl.flow_registry_reset! }

  let(:flow) { Browserctl.lookup_flow("basic_auth") }

  it "registers under 'basic_auth' with the right metadata" do
    expect(flow).to be_a(Browserctl::Flow)
    expect(flow.version_string).to eq("1.0.0")
    expect(flow.min_browserctl_version).to eq("0.11.0")
    expect(flow.param_defs[:password].secret).to be true
  end

  it "navigates with userinfo embedded in the URL" do
    expect(page).to receive(:navigate).with("https://alice:s3cret@example.com/")
    flow.run(page: page, url: "https://example.com/", username: "alice", password: "s3cret")
  end

  it "URL-encodes special characters in credentials" do
    expect(page).to receive(:navigate) do |url|
      expect(url).to start_with("https://")
      expect(url).to include("a%40b")     # @ encoded
      expect(url).to include("p%2Fass")   # / encoded
      expect(url).to include("@example.com/")
    end
    flow.run(page: page, url: "https://example.com/", username: "a@b", password: "p/ass")
  end

  it "raises a precondition error without a page proxy" do
    expect { flow.run(url: "https://example.com/", username: "a", password: "b") }
      .to raise_error(Browserctl::FlowPreconditionError, /page proxy/)
  end

  it "requires url, username, and password" do
    %i[url username password].each do |missing|
      args = { page: page, url: "https://x.test/", username: "u", password: "p" }
      args.delete(missing)
      expect { flow.run(**args) }.to raise_error(Browserctl::FlowParamError, /#{missing}/)
    end
  end
end

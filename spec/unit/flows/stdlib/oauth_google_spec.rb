# frozen_string_literal: true

require "spec_helper"
require "browserctl/flows/stdlib/oauth_google"

RSpec.describe "stdlib flow: oauth_google" do
  let(:page) { instance_double(Browserctl::PageProxy) }

  before do
    Browserctl.flow_registry_reset!
    load File.expand_path("../../../../lib/browserctl/flows/stdlib/oauth_google.rb", __dir__)
  end
  after { Browserctl.flow_registry_reset! }

  let(:flow) { Browserctl.lookup_flow("oauth_google") }

  it "registers under 'oauth_google' with version 1.0.0" do
    expect(flow).to be_a(Browserctl::Flow)
    expect(flow.version_string).to eq("1.0.0")
  end

  it "clicks the default continue selector when on a consent URL" do
    allow(page).to receive(:url)
      .and_return("https://accounts.google.com/signin/oauth/consent?client_id=abc")
    expect(page).to receive(:click).with('button[jsname="LgbsSe"]')

    flow.run(page: page)
  end

  it "matches /oauth path variants too" do
    allow(page).to receive(:url).and_return("https://accounts.google.com/o/oauth2/auth")
    expect(page).to receive(:click)

    flow.run(page: page)
  end

  it "honors a custom continue_selector" do
    allow(page).to receive(:url).and_return("https://accounts.google.com/signin/oauth/consent")
    expect(page).to receive(:click).with("[data-test='allow']")

    flow.run(page: page, continue_selector: "[data-test='allow']")
  end

  it "raises a precondition error when not on accounts.google.com" do
    allow(page).to receive(:url).and_return("https://example.com/")

    expect { flow.run(page: page) }
      .to raise_error(Browserctl::FlowPreconditionError, /consent/)
  end

  it "raises a precondition error on accounts.google.com without an oauth path" do
    allow(page).to receive(:url).and_return("https://accounts.google.com/Logout")

    expect { flow.run(page: page) }
      .to raise_error(Browserctl::FlowPreconditionError, /consent/)
  end
end

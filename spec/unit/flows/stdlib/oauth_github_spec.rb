# frozen_string_literal: true

require "spec_helper"
require "browserctl/flows/stdlib/oauth_github"

RSpec.describe "stdlib flow: oauth_github" do
  let(:page) { instance_double(Browserctl::PageProxy) }

  before do
    Browserctl.flow_registry_reset!
    load File.expand_path("../../../../lib/browserctl/flows/stdlib/oauth_github.rb", __dir__)
  end
  after { Browserctl.flow_registry_reset! }

  let(:flow) { Browserctl.lookup_flow("oauth_github") }

  it "registers under 'oauth_github' with version 1.0.0" do
    expect(flow).to be_a(Browserctl::Flow)
    expect(flow.version_string).to eq("1.0.0")
  end

  it "clicks the default authorize selector when on the consent URL" do
    allow(page).to receive(:url).and_return("https://github.com/login/oauth/authorize?client_id=abc")
    expect(page).to receive(:click).with('button[name="authorize"][value="1"]')

    flow.run(page: page)
  end

  it "honors a custom authorize_selector" do
    allow(page).to receive(:url).and_return("https://ghe.example.com/login/oauth/authorize")
    expect(page).to receive(:click).with(".enterprise-authorize")

    flow.run(page: page, authorize_selector: ".enterprise-authorize")
  end

  it "raises a precondition error when not on a consent URL" do
    allow(page).to receive(:url).and_return("https://github.com/repos/")

    expect { flow.run(page: page) }
      .to raise_error(Browserctl::FlowPreconditionError, /consent/)
  end

  it "raises a precondition error without a page proxy" do
    # The pre runs first, fails on page.url for nil page
    expect { flow.run }
      .to raise_error(Browserctl::FlowPreconditionError)
  end
end

# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "browserctl/flows/stdlib/magic_link_email"

RSpec.describe "stdlib flow: magic_link_email" do
  let(:page) { instance_double(Browserctl::PageProxy) }

  before do
    Browserctl.flow_registry_reset!
    load File.expand_path("../../../../lib/browserctl/flows/stdlib/magic_link_email.rb", __dir__)
  end
  after { Browserctl.flow_registry_reset! }

  let(:flow) { Browserctl.lookup_flow("magic_link_email") }

  def with_stdin(input)
    original = $stdin
    $stdin = StringIO.new(input)
    yield
  ensure
    $stdin = original
  end

  def silence_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original
  end

  it "registers under 'magic_link_email'" do
    expect(flow).to be_a(Browserctl::Flow)
    expect(flow.version_string).to eq("1.0.0")
  end

  it "prompts the human and navigates to the pasted link" do
    expect(page).to receive(:navigate).with("https://app.example.com/auth/abc123")
    out = silence_stderr do
      with_stdin("https://app.example.com/auth/abc123\n") { flow.run(page: page) }
    end
    expect(out).to include("[browserctl]")
    expect(out).to include("Paste the magic link")
  end

  it "uses a custom prompt when given" do
    allow(page).to receive(:navigate)
    out = silence_stderr do
      with_stdin("https://x.test/\n") { flow.run(page: page, prompt: "Magic link?") }
    end
    expect(out).to include("Magic link?")
  end

  it "fails when the user provides an empty line" do
    silence_stderr do
      with_stdin("\n") do
        expect { flow.run(page: page) }.to raise_error(Browserctl::FlowStepError, /no magic link/)
      end
    end
  end

  it "fails when the link is not http(s)" do
    silence_stderr do
      with_stdin("javascript:alert(1)\n") do
        expect { flow.run(page: page) }
          .to raise_error(Browserctl::FlowStepError, /must start with http/)
      end
    end
  end

  it "raises a precondition error without a page proxy" do
    expect { flow.run }.to raise_error(Browserctl::FlowPreconditionError, /page proxy/)
  end
end

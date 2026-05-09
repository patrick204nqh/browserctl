# frozen_string_literal: true

require "spec_helper"
require "browserctl/workflow"

RSpec.describe "WorkflowContext#load_state" do
  let(:client) { instance_double(Browserctl::Client) }
  let(:ctx)    { Browserctl::WorkflowContext.new({}, client) }

  it "returns the load result when the bundle is fresh" do
    allow(client).to receive(:state_load).with("github").and_return(ok: true, cookies: 4)
    expect(ctx.load_state("github")).to eq(ok: true, cookies: 4)
  end

  it "auto-rotates via the bundle's bound flow when AUTH_REQUIRED is returned" do
    auth_response = {
      error: "expired cookies",
      code: "AUTH_REQUIRED",
      state: "github",
      suggested_flow: "github_login"
    }
    fresh_response = { ok: true, cookies: 4 }

    allow(client).to receive(:state_load).with("github").and_return(auth_response)
    allow(client).to receive(:state_load).with("github", skip_auth_check: true).and_return(fresh_response)
    allow(client).to receive(:state_save).with("github").and_return(ok: true)
    allow(ctx).to receive(:invoke).with("github_login")

    result = ctx.load_state("github")

    expect(ctx).to have_received(:invoke).with("github_login")
    expect(client).to have_received(:state_save).with("github")
    expect(result).to include(rotated: true, ok: true, cookies: 4)
  end

  it "honours an explicit on_auth_required: hook over the auto path" do
    auth_response = { error: "expired", code: "AUTH_REQUIRED", suggested_flow: "ignored_flow" }
    allow(client).to receive(:state_load).with("github").and_return(auth_response)
    allow(client).to receive(:state_load).with("github", skip_auth_check: true).and_return(ok: true)
    allow(client).to receive(:state_save).with("github").and_return(ok: true)
    allow(ctx).to receive(:invoke)

    custom_ran = false
    ctx.load_state("github", on_auth_required: -> { custom_ran = true })

    expect(custom_ran).to be(true)
    expect(ctx).not_to have_received(:invoke)
  end

  it "raises a WorkflowError when AUTH_REQUIRED hits and no flow is bound" do
    allow(client).to receive(:state_load).with("github")
                                         .and_return(error: "expired", code: "AUTH_REQUIRED")
    expect { ctx.load_state("github") }
      .to raise_error(Browserctl::WorkflowError, /no bound flow/)
  end

  it "raises when the rotated flow still fails the auth check" do
    allow(client).to receive(:state_load).with("github")
                                         .and_return(error: "expired", code: "AUTH_REQUIRED",
                                                     suggested_flow: "github_login")
    allow(client).to receive(:state_save).with("github").and_return(ok: true)
    allow(client).to receive(:state_load).with("github", skip_auth_check: true)
                                         .and_return(error: "still bad")
    allow(ctx).to receive(:invoke).with("github_login")

    expect { ctx.load_state("github") }
      .to raise_error(Browserctl::WorkflowError, /still bad/)
  end
end

RSpec.describe "WorkflowContext#save_state" do
  let(:client) { instance_double(Browserctl::Client) }
  let(:ctx)    { Browserctl::WorkflowContext.new({}, client) }

  it "calls state_save with the flow binding" do
    expect(client).to receive(:state_save).with("github", flow: "github_login",
                                                          origins: nil, passphrase: nil)
                                          .and_return(ok: true)
    ctx.save_state("github", flow: :github_login)
  end

  it "raises when the daemon returns an error" do
    allow(client).to receive(:state_save).and_return(error: "not allowed")
    expect { ctx.save_state("github") }.to raise_error(Browserctl::WorkflowError, "not allowed")
  end
end

RSpec.describe "WorkflowContext#load_session deprecation" do
  let(:client) { instance_double(Browserctl::Client) }
  let(:ctx)    { Browserctl::WorkflowContext.new({}, client) }

  it "warns when fallback: is used" do
    allow(client).to receive(:session_load).with("my-session").and_return(ok: true)
    expect { ctx.load_session("my-session", fallback: :setup) }
      .to output(/DEPRECATION.*load_state/m).to_stderr
  end

  it "does not warn when called without fallback / expired_if" do
    allow(client).to receive(:session_load).with("my-session").and_return(ok: true)
    expect { ctx.load_session("my-session") }.not_to output(/DEPRECATION/).to_stderr
  end
end

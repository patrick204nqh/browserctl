# frozen_string_literal: true

require "spec_helper"
require "browserctl/workflow/recovery_manager"
require "browserctl/errors"

RSpec.describe Browserctl::Workflow::RecoveryManager do
  let(:client)  { instance_double(Browserctl::Client) }
  let(:context) { instance_double("WorkflowContext", client: client) }
  let(:manager) { described_class.new(context) }

  describe ".auth_required?" do
    it "returns true when symbol code is AUTH_REQUIRED" do
      expect(described_class.auth_required?(code: "AUTH_REQUIRED")).to be(true)
    end

    it "returns true when string code is AUTH_REQUIRED" do
      expect(described_class.auth_required?("code" => "AUTH_REQUIRED")).to be(true)
    end

    it "returns false on a fresh ok response" do
      expect(described_class.auth_required?(ok: true, cookies: 4)).to be(false)
    end

    it "returns false on other error codes" do
      expect(described_class.auth_required?(code: "NOT_FOUND")).to be(false)
    end
  end

  describe "#recover" do
    let(:auth_response) do
      { error: "expired cookies", code: "AUTH_REQUIRED",
        state: "github", suggested_flow: "github_login" }
    end
    let(:fresh_response) { { ok: true, cookies: 4 } }

    before do
      allow(client).to receive(:state_save).with("github").and_return(ok: true)
      allow(client).to receive(:state_load).with("github", skip_auth_check: true)
                                           .and_return(fresh_response)
      allow(client).to receive(:page_list).and_return(pages: ["work"])
      allow(context).to receive(:invoke)
    end

    it "invokes the suggested flow with the first open page, re-saves and reloads" do
      result = manager.recover("github", auth_response)

      expect(context).to have_received(:invoke).with("github_login", page: "work")
      expect(client).to have_received(:state_save).with("github")
      expect(client).to have_received(:state_load).with("github", skip_auth_check: true)
      expect(result).to include(rotated: true, ok: true, cookies: 4)
    end

    it "passes page: nil when no pages are open (defence-in-depth)" do
      allow(client).to receive(:page_list).and_return(pages: [])

      manager.recover("github", auth_response)

      expect(context).to have_received(:invoke).with("github_login", page: nil)
    end

    it "honours an explicit on_auth_required override over the auto path" do
      ran = false
      manager.recover("github", auth_response, on_auth_required: -> { ran = true })

      expect(ran).to be(true)
      expect(context).not_to have_received(:invoke)
    end

    it "raises WorkflowError when no flow is bound and no override given" do
      expect do
        manager.recover("github", { error: "expired", code: "AUTH_REQUIRED" })
      end.to raise_error(Browserctl::WorkflowError, /no bound flow/)
    end

    it "raises WorkflowError when state_save fails after rotation" do
      allow(client).to receive(:state_save).with("github").and_return(error: "save kaput")

      expect { manager.recover("github", auth_response) }
        .to raise_error(Browserctl::WorkflowError, "save kaput")
    end

    it "raises WorkflowError when the rotated reload still fails" do
      allow(client).to receive(:state_load).with("github", skip_auth_check: true)
                                           .and_return(error: "still bad")

      expect { manager.recover("github", auth_response) }
        .to raise_error(Browserctl::WorkflowError, "still bad")
    end

    it "reads suggested_flow under string keys too" do
      string_auth = { "error" => "expired", "code" => "AUTH_REQUIRED",
                      "suggested_flow" => "github_login" }

      manager.recover("github", string_auth)

      expect(context).to have_received(:invoke).with("github_login", page: "work")
    end
  end
end

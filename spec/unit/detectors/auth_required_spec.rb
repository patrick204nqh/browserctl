# frozen_string_literal: true

require "browserctl/detectors"

RSpec.describe Browserctl::Detectors::AuthRequired do
  let(:page) { double("Page", current_url: url) }
  let(:url)  { "https://app.example.com/dashboard" }

  describe ".detect — URL check" do
    %w[
      https://app.example.com/login
      https://app.example.com/login/
      https://app.example.com/login?next=/dash
      https://app.example.com/signin
      https://app.example.com/sign-in
      https://app.example.com/sign_in
      https://app.example.com/auth/login
      https://app.example.com/auth/signin
      https://example.com/account/login
    ].each do |login_url|
      it "fires for #{login_url}" do
        result = described_class.detect(double(current_url: login_url))
        expect(result.triggered).to be(true)
        expect(result.code).to eq("redirect_login")
      end
    end

    it "does not fire for /loginhelp or /signing-up" do
      expect(described_class.detect(double(current_url: "https://x/loginhelp")).triggered).to be(false)
      expect(described_class.detect(double(current_url: "https://x/signing-up")).triggered).to be(false)
    end
  end

  describe ".detect — recent responses" do
    it "fires on the most recent 401" do
      responses = [
        { status: 200, url: "https://api/me" },
        { status: 401, url: "https://api/secret" }
      ]
      result = described_class.detect(page, recent_responses: responses)
      expect(result.triggered).to be(true)
      expect(result.code).to eq("http_401")
      expect(result.reason).to include("https://api/secret")
    end

    it "fires on 403" do
      result = described_class.detect(page, recent_responses: [{ status: 403, url: "https://api/x" }])
      expect(result.code).to eq("http_403")
    end

    it "ignores 200/404/500" do
      result = described_class.detect(page, recent_responses: [
                                        { status: 200, url: "https://x" },
                                        { status: 404, url: "https://x" }
                                      ])
      expect(result.triggered).to be(false)
    end

    it "tolerates string-keyed hashes" do
      result = described_class.detect(page,
                                      recent_responses: [{ "status" => 401, "url" => "https://api/x" }])
      expect(result.triggered).to be(true)
    end
  end

  describe ".detect — cookie expiry" do
    let(:past)   { (Time.now - 86_400).to_i }
    let(:future) { (Time.now + 86_400).to_i }

    it "fires when any cookie has expired" do
      result = described_class.detect(page, cookies: [
                                        { name: "fresh", expires: future },
                                        { name: "stale", expires: past }
                                      ])
      expect(result.triggered).to be(true)
      expect(result.code).to eq("cookie_expired")
      expect(result.reason).to include("stale")
    end

    it "skips when cookies is nil (caller opted out)" do
      result = described_class.detect(page, cookies: nil)
      expect(result.triggered).to be(false)
    end

    it "ignores session cookies (expires <= 0)" do
      result = described_class.detect(page, cookies: [{ name: "session", expires: 0 }])
      expect(result.triggered).to be(false)
    end
  end

  describe ".detect — passthrough" do
    it "carries suggested_flow into the result" do
      result = described_class.detect(double(current_url: "https://x/login"), suggested_flow: "site_login")
      expect(result.suggested_flow).to eq("site_login")
    end

    it "returns a non-triggered Result when nothing matches" do
      result = described_class.detect(page)
      expect(result.triggered).to be(false)
      expect(result.code).to be_nil
    end
  end

  describe "module-level shortcuts" do
    it "Detectors.auth_required? returns the boolean" do
      expect(Browserctl::Detectors.auth_required?(double(current_url: "https://x/login"))).to be(true)
      expect(Browserctl::Detectors.auth_required?(double(current_url: "https://x/dash"))).to be(false)
    end

    it "Detectors.auth_required returns the Result" do
      result = Browserctl::Detectors.auth_required(double(current_url: "https://x/login"))
      expect(result).to be_a(Browserctl::Detectors::AuthRequired::Result)
    end
  end
end

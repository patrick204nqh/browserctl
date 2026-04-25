# frozen_string_literal: true

require "spec_helper"
require "browserctl/detectors"

RSpec.describe Browserctl::Detectors do
  let(:page) { instance_double("Ferrum::Page") }

  describe ".cloudflare?" do
    it "returns false for a clean page" do
      allow(page).to receive(:current_url).and_return("https://example.com/login")
      allow(page).to receive(:body).and_return("<html><body>Login</body></html>")
      expect(described_class.cloudflare?(page)).to be false
    end

    it "detects challenge-platform in URL" do
      allow(page).to receive(:current_url).and_return("https://challenges.cloudflare.com/cdn-cgi/challenge-platform/h/b")
      allow(page).to receive(:body).and_return("")
      expect(described_class.cloudflare?(page)).to be true
    end

    it "detects cf-challenge-running in body" do
      allow(page).to receive(:current_url).and_return("https://example.com")
      allow(page).to receive(:body).and_return('<div class="cf-challenge-running"></div>')
      expect(described_class.cloudflare?(page)).to be true
    end

    it "detects Just a moment... in body" do
      allow(page).to receive(:current_url).and_return("https://example.com")
      allow(page).to receive(:body).and_return("<title>Just a moment...</title>")
      expect(described_class.cloudflare?(page)).to be true
    end

    it "detects cf_chl_opt in body" do
      allow(page).to receive(:current_url).and_return("https://example.com")
      allow(page).to receive(:body).and_return("window.cf_chl_opt={}")
      expect(described_class.cloudflare?(page)).to be true
    end
  end
end

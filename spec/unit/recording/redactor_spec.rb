# frozen_string_literal: true

require "browserctl/recording"

RSpec.describe Browserctl::Recording::Redactor do
  describe ".infer_secret_field" do
    it "returns nil for nil selector" do
      expect(described_class.infer_secret_field(nil)).to be_nil
    end

    it "returns nil for selectors with no secret-shaped tokens" do
      expect(described_class.infer_secret_field("input[name='email']")).to be_nil
    end

    it "extracts a normalised name when the selector matches a secret token" do
      expect(described_class.infer_secret_field("input[name='password']")).to eq("password")
    end

    it "normalises hyphens and case (api_key)" do
      expect(described_class.infer_secret_field("[data-test='Api-Key']")).to eq("api_key")
    end

    it "matches client_secret variants" do
      expect(described_class.infer_secret_field("#client-secret")).to eq("client_secret")
    end
  end

  describe ".redact_url" do
    it "returns the url unchanged when there is no query string" do
      url = "https://example.com/path"
      expect(described_class.redact_url(url)).to eq(url)
    end

    it "redacts sensitive parameter values" do
      out = described_class.redact_url("https://example.com/cb?token=abc&id=1")
      expect(out).to eq("https://example.com/cb?token=[REDACTED]&id=1")
    end

    it "redacts api_key, secret, code, access_token, client_secret, state" do
      sensitive = %w[api_key secret code access_token client_secret state token key auth]
      sensitive.each do |key|
        out = described_class.redact_url("https://example.com/?#{key}=v")
        expect(out).to include("#{key}=[REDACTED]"), "expected #{key} to be redacted, got #{out}"
      end
    end

    it "preserves non-sensitive query params" do
      out = described_class.redact_url("https://example.com/?id=1&name=patrick")
      expect(out).to eq("https://example.com/?id=1&name=patrick")
    end

    it "returns the url unchanged on URI parse failure" do
      bad = "http://exa mple.com/?token=x"
      expect(described_class.redact_url(bad)).to eq(bad)
    end
  end
end

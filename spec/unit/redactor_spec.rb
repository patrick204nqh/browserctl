# frozen_string_literal: true

require "spec_helper"
require "browserctl/redactor"

RSpec.describe Browserctl::Redactor do
  describe "#redact" do
    it "replaces a known secret value with [REDACTED]" do
      redactor = described_class.new(secrets: ["sk-supersecret"])
      expect(redactor.redact("token=sk-supersecret bar")).to eq("token=[REDACTED] bar")
    end

    it "redacts longer matches before shorter ones" do
      redactor = described_class.new(secrets: %w[abcd abcdef])
      # If "abcd" was applied first, "ef" would be left dangling. Longest-first
      # ensures the full "abcdef" is replaced as one unit.
      expect(redactor.redact("xx abcdef yy")).to eq("xx [REDACTED] yy")
    end

    it "skips empty and short secret values" do
      redactor = described_class.new(secrets: ["", nil, "abc", "longenough"])
      expect(redactor.redact("abc longenough")).to eq("abc [REDACTED]")
    end

    it "is case-sensitive" do
      redactor = described_class.new(secrets: ["SecretValue"])
      expect(redactor.redact("secretvalue SecretValue")).to eq("secretvalue [REDACTED]")
    end

    it "returns nil unchanged" do
      expect(described_class.new(secrets: ["abcd"]).redact(nil)).to be_nil
    end

    it "returns the original string when no secrets are configured" do
      expect(described_class.new(secrets: []).redact("hello")).to eq("hello")
    end

    it "redacts repeated occurrences" do
      redactor = described_class.new(secrets: ["mysecret"])
      expect(redactor.redact("mysecret and mysecret again"))
        .to eq("[REDACTED] and [REDACTED] again")
    end
  end

  describe ".from_env" do
    it "picks up values from variables matching well-known patterns" do
      env = {
        "GITHUB_TOKEN" => "ghp_abcdef123456",
        "API_KEY" => "key_abcd",
        "DB_PASSWORD" => "hunter22",
        "OAUTH_SECRET" => "shhh1234",
        "PATH" => "/usr/bin",
        "HOME" => "/home/me"
      }
      redactor = described_class.from_env(env: env)
      out = redactor.redact("ghp_abcdef123456 key_abcd hunter22 shhh1234 /usr/bin")
      expect(out).to eq("[REDACTED] [REDACTED] [REDACTED] [REDACTED] /usr/bin")
    end

    it "merges in extra runtime-captured values" do
      env = { "PATH" => "/usr/bin" }
      redactor = described_class.from_env(env: env, extra: ["runtime-secret"])
      expect(redactor.redact("hi runtime-secret")).to eq("hi [REDACTED]")
    end
  end
end

# frozen_string_literal: true

require "spec_helper"
require "browserctl/policy"

RSpec.describe Browserctl::Policy do
  describe ".allowed_navigation?" do
    context "when BROWSERCTL_ALLOWED_DOMAINS is not set" do
      before { ENV.delete("BROWSERCTL_ALLOWED_DOMAINS") }

      it "allows any URL" do
        expect(described_class.allowed_navigation?("https://evil.com/steal")).to be true
      end
    end

    context "when BROWSERCTL_ALLOWED_DOMAINS=example.com,staging.example.com" do
      before { ENV["BROWSERCTL_ALLOWED_DOMAINS"] = "example.com,staging.example.com" }
      after  { ENV.delete("BROWSERCTL_ALLOWED_DOMAINS") }

      it "allows exact domain match" do
        expect(described_class.allowed_navigation?("https://example.com/page")).to be true
      end

      it "allows subdomain of listed domain" do
        expect(described_class.allowed_navigation?("https://app.example.com/login")).to be true
      end

      it "allows the second listed domain" do
        expect(described_class.allowed_navigation?("https://staging.example.com/")).to be true
      end

      it "blocks an unlisted domain" do
        expect(described_class.allowed_navigation?("https://evil.com/phish")).to be false
      end

      it "blocks a URL that only prefix-matches (not a real subdomain)" do
        expect(described_class.allowed_navigation?("https://notexample.com/")).to be false
      end

      it "allows uppercase domain (case-insensitive match)" do
        expect(described_class.allowed_navigation?("https://EXAMPLE.COM/page")).to be true
      end

      it "allows mixed-case subdomain" do
        expect(described_class.allowed_navigation?("https://App.Example.Com/login")).to be true
      end

      it "blocks uppercase unlisted domain" do
        expect(described_class.allowed_navigation?("https://EVIL.COM/phish")).to be false
      end
    end

    context "when URL is invalid" do
      before { ENV["BROWSERCTL_ALLOWED_DOMAINS"] = "example.com" }
      after  { ENV.delete("BROWSERCTL_ALLOWED_DOMAINS") }

      it "returns false for garbage input" do
        expect(described_class.allowed_navigation?("not a url")).to be false
      end
    end
  end
end

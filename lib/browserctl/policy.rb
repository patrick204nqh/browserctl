# frozen_string_literal: true

require "uri"

module Browserctl
  module Policy
    # Returns true if the URL is permitted by the domain policy.
    # When BROWSERCTL_ALLOWED_DOMAINS is unset, all URLs are allowed.
    # @param url [String] the URL to check
    # @return [Boolean]
    def self.allowed_navigation?(url)
      domains = allowed_domains
      return true if domains.empty?

      host_matches?(URI.parse(url).host, domains)
    rescue URI::InvalidURIError
      false
    end

    def self.allowed_domains
      raw = ENV.fetch("BROWSERCTL_ALLOWED_DOMAINS", nil)
      return [] unless raw&.match?(/\S/)

      raw.split(",").map(&:strip).reject(&:empty?)
    end

    def self.host_matches?(host, domains)
      return false unless host

      domains.any? { |d| host == d || host.end_with?(".#{d}") }
    end

    private_class_method :allowed_domains, :host_matches?
  end
end

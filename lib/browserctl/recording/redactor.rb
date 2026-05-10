# frozen_string_literal: true

require "uri"

module Browserctl
  class Recording
    # Secret-aware redaction helpers used while a recording is being
    # captured. Two responsibilities:
    #
    # 1. Inferring whether a `fill` selector is targeting a secret-shaped
    #    field, so the generated workflow can wire a `secret_ref:` param.
    # 2. Stripping sensitive query-string values out of recorded URLs so
    #    they never reach disk.
    module Redactor
      # Query-string parameter names whose values are scrubbed when a
      # navigate/page_open URL is recorded.
      SENSITIVE_PARAM_PATTERN = /\A(token|key|secret|auth|code|access_token|api_key|client_secret|state)\z/ix

      # Selector tokens that signal a fill is targeting a secret-shaped
      # field. The captured group is used as the inferred field name; that
      # name later drives the generated `secret_ref:` placeholder.
      SECRET_FIELD_PATTERN = Regexp.new(
        '\b(password|passwd|api[_-]?key|token|secret|otp|pin|client[_-]?secret|access[_-]?token)\b',
        Regexp::IGNORECASE
      )

      module_function

      # Returns a normalised secret-field name (e.g. "api_key") inferred
      # from the selector, or nil when the selector is missing or does not
      # match the secret-field pattern.
      def infer_secret_field(selector)
        return nil unless selector

        match = selector.match(SECRET_FIELD_PATTERN)
        return nil unless match

        match[1].downcase.gsub(/[^a-z0-9]/, "_")
      end

      # Returns `url` with any sensitive query parameter values replaced
      # by `[REDACTED]`. URLs that fail to parse are returned unchanged.
      def redact_url(url)
        uri = URI.parse(url)
        return url if uri.query.nil?

        uri.query = uri.query.gsub(/([^&=]+)=([^&]*)/) do |full_match|
          raw_key = ::Regexp.last_match(1)
          key = URI.decode_www_form_component(raw_key)
          key =~ SENSITIVE_PARAM_PATTERN ? "#{raw_key}=[REDACTED]" : full_match
        end
        uri.to_s
      rescue URI::InvalidURIError
        url
      end
    end
  end
end

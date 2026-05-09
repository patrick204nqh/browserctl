# frozen_string_literal: true

require "uri"
require_relative "../../flow"

# Authenticates with an HTTP Basic Auth-protected URL by navigating to it
# with credentials embedded in the URL. This avoids the native auth
# dialog entirely; Chromium ingests the userinfo and supplies it on the
# request without prompting.
#
# Use for sites where the auth challenge is real HTTP Basic. For form-
# based "username + password" logins, use a workflow with `page.fill`.
Browserctl.flow("basic_auth") do
  version "1.0.0"
  requires_browserctl "0.11.0"
  desc "Navigate to an HTTP Basic Auth URL using credentials embedded in the URL."

  param :url,      required: true
  param :username, required: true
  param :password, required: true, secret: true

  precondition("page proxy is present") { !page.nil? }

  step("navigate with embedded credentials") do
    parsed = URI.parse(url)
    parsed.user     = URI.encode_www_form_component(username)
    parsed.password = URI.encode_www_form_component(password)
    page.navigate(parsed.to_s)
  end
end

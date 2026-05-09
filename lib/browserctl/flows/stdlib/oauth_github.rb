# frozen_string_literal: true

require_relative "../../flow"

# Clicks the "Authorize <app>" button on a GitHub OAuth consent screen.
#
# Assumes the user is already signed in to GitHub and the page is parked
# on the consent URL — this flow does not handle the credential entry
# step. Use a separate workflow or flow to land on the consent page first.
Browserctl.flow("oauth_github") do
  version "1.0.0"
  requires_browserctl "0.11.0"
  desc "Click the Authorize button on a GitHub OAuth consent screen."

  # The default selector targets the green Authorize submit button on
  # github.com/login/oauth/authorize. GitHub keeps name="authorize" stable
  # across UI revisions; override only if you're testing against a forked
  # GitHub Enterprise instance with a customised template.
  param :authorize_selector, default: 'button[name="authorize"][value="1"]'

  precondition("on a github oauth consent page") do
    page.url.include?("/login/oauth/authorize")
  end

  step("click authorize") do
    page.click(authorize_selector)
  end
end

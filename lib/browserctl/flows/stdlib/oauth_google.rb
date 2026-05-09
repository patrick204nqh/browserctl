# frozen_string_literal: true

require_relative "../../flow"

# Clicks the Continue / Allow button on a Google OAuth consent screen.
#
# Assumes the user is already signed in to Google and the page is parked
# on accounts.google.com showing the consent prompt. This flow does not
# pick an account from the chooser, enter a password, or solve 2FA —
# compose those before calling this flow.
#
# Google rotates consent UI more often than GitHub, so the default
# selector is a best-effort match against the modern Material 3 button.
# Override if your account or app version sees a different layout.
Browserctl.flow("oauth_google") do
  version "1.0.0"
  requires_browserctl "0.11.0"
  desc "Click the Continue/Allow button on a Google OAuth consent screen."

  param :continue_selector, default: 'button[jsname="LgbsSe"]'

  precondition("on a google oauth consent page") do
    url = page.url
    url.include?("accounts.google.com") && (url.include?("/oauth") || url.include?("/signin/oauth"))
  end

  step("click continue") do
    page.click(continue_selector)
  end
end

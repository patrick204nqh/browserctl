# frozen_string_literal: true

# Demonstrates the authenticate-once, reuse-forever pattern.
#
# The first run (no saved session) invokes `login_once` to authenticate,
# which saves the session. Every subsequent run loads the saved session
# directly — no re-authentication needed.
#
# `expired_if:` detects when the saved session exists but server-side auth
# has lapsed (rotated cookie, token TTL), and automatically re-authenticates.
#
# Run:
#   browserctl workflow run examples/session_reuse.rb \
#     --app_url https://the-internet.herokuapp.com \
#     --username tomsmith \
#     --password "SuperSecretPassword!"
#
# On the first run: authenticates and saves the session.
# On subsequent runs: loads the session and skips the login page entirely.

# --- Step 1: define the login workflow (run once, triggered automatically on missing/expired session) ---

Browserctl.workflow "session_reuse/login_once" do
  desc "Authenticate and save session — called automatically by session_reuse when needed"

  param :app_url,  required: true
  param :username, required: true
  param :password, required: true, secret: true

  step "open login page" do
    open_page(:main, url: "#{app_url}/login")
  end

  step "fill and submit credentials" do
    page(:main).fill("input#username", username)
    page(:main).fill("input#password", password)
    page(:main).click("button[type=submit]")
  end

  step "verify login succeeded" do
    assert page(:main).url.include?("/secure"), "login failed — still on login page"
  end

  step "save authenticated session" do
    save_session("session_reuse_demo")
    puts "  ✓ Session saved — future runs will skip this step"
  end
end

# --- Step 2: the main workflow that reuses the saved session ---

Browserctl.workflow "session_reuse" do
  desc "Authenticate once, reuse forever — demonstrates load_session with fallback and expired_if"

  param :app_url,  default: "https://the-internet.herokuapp.com"
  param :username, default: "tomsmith"
  param :password, default: "SuperSecretPassword!", secret: true

  step "restore session or log in" do
    load_session("session_reuse_demo",
      fallback: "session_reuse/login_once",
      expired_if: -> {
        page(:main).navigate("#{app_url}/secure")
        !page(:main).url.include?("/secure")
      }
    )
    puts "  ✓ Session ready — authenticated as #{username}"
  end

  step "do authenticated work" do
    page(:main).navigate("#{app_url}/secure")
    heading = page(:main).evaluate("document.querySelector('h2')?.textContent?.trim()")
    assert heading&.include?("Secure Area"), "expected to be in secure area, got: #{heading.inspect}"
    puts "  ✓ Landed in secure area without re-authenticating"
  end
end

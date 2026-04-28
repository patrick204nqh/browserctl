# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/login" do
  desc "Auth page: fill credentials, verify success message, logout"

  param :username,        default: "admin"
  param :password,        default: "admin", secret: true
  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/test_automation_practices_login.png")

  step "open auth page" do
    open_page(:main, url: "#{base_url}/#/auth")
  end

  step "fill and submit credentials" do
    page(:main).fill("[data-test='username-input']", username)
    page(:main).fill("[data-test='password-input']", password)
    page(:main).click("[data-test='login-button']")
  end

  step "verify successful login" do
    page(:main).wait("[data-test='auth-success']", timeout: 10)
    msg = page(:main).evaluate("document.querySelector('[data-test=\"auth-success\"]')?.innerText?.trim()")
    assert msg&.length&.positive?, "expected a success message, got: #{msg.inspect}"
    page(:main).screenshot(path: screenshot_path)
  end

  step "logout and verify form reappears" do
    page(:main).click("[data-test='logout-button']")
    page(:main).wait("[data-test='login-button']", timeout: 5)
    visible = page(:main).evaluate("!!document.querySelector('[data-test=\"login-button\"]')")
    assert visible, "expected login form to reappear after logout"
  end
end

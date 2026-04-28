# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/login_negative" do
  desc "Auth page: invalid credentials show an error message"

  param :base_url, default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path,
        default: File.expand_path(".browserctl/screenshots/test_automation_practices_login_negative.png")

  step "open auth page" do
    open_page(:main, url: "#{base_url}/#/auth")
  end

  step "submit wrong credentials" do
    page(:main).fill("[data-test='username-input']", "wronguser")
    page(:main).fill("[data-test='password-input']", "wrongpass")
    page(:main).click("[data-test='login-button']")
  end

  step "verify error is shown and success is absent" do
    page(:main).wait("[data-test='auth-error']", timeout: 10)
    error = client.evaluate("main", "document.querySelector('[data-test=\"auth-error\"]')?.innerText?.trim()")[:result]
    assert error&.length&.positive?, "expected an error message, got: #{error.inspect}"
    no_success = client.evaluate("main", "!document.querySelector('[data-test=\"auth-success\"]')")[:result]
    assert no_success, "expected no success element when credentials are invalid"
    page(:main).screenshot(path: screenshot_path)
  end
end

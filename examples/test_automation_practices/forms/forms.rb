# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/forms/forms" do
  desc "Forms page: trigger inline validation errors, then submit a valid form"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/tap_forms_forms.png")

  step "open forms page" do
    open_page(:main, url: "#{base_url}/#/forms")
    page(:main).wait("[data-test='login-form']", timeout: 10)
  end

  step "submit empty form — all three fields show errors" do
    page(:main).click("[data-test='submit-button']")
    page(:main).wait("[data-test='username-error']", timeout: 5)
    username_err = page(:main).evaluate("document.querySelector('[data-test=\"username-error\"]')?.textContent?.trim()")
    email_err    = page(:main).evaluate("document.querySelector('[data-test=\"email-error\"]')?.textContent?.trim()")
    password_err = page(:main).evaluate("document.querySelector('[data-test=\"password-error\"]')?.textContent?.trim()")
    assert username_err&.length&.positive?, "expected username error, got: #{username_err.inspect}"
    assert email_err&.length&.positive?,    "expected email error, got: #{email_err.inspect}"
    assert password_err&.length&.positive?, "expected password error, got: #{password_err.inspect}"
  end

  step "fill invalid email — email error shown" do
    page(:main).fill("[data-test='email-input']", "not-an-email")
    page(:main).click("[data-test='submit-button']")
    page(:main).wait("[data-test='email-error']", timeout: 5)
    email_err = page(:main).evaluate("document.querySelector('[data-test=\"email-error\"]')?.textContent?.trim()")
    assert email_err&.length&.positive?, "expected email format error, got: #{email_err.inspect}"
  end

  step "fill valid credentials and submit — no errors shown" do
    page(:main).fill("[data-test='username-input']", "testuser")
    page(:main).fill("[data-test='email-input']", "test@example.com")
    page(:main).fill("[data-test='password-input']", "password123")
    page(:main).click("[data-test='submit-button']")
    sleep 0.5
    username_err = page(:main).evaluate("!!document.querySelector('[data-test=\"username-error\"]')")
    email_err    = page(:main).evaluate("!!document.querySelector('[data-test=\"email-error\"]')")
    password_err = page(:main).evaluate("!!document.querySelector('[data-test=\"password-error\"]')")
    assert !username_err, "expected no username error on valid submit"
    assert !email_err,    "expected no email error on valid submit"
    assert !password_err, "expected no password error on valid submit"
    page(:main).screenshot(path: screenshot_path)
  end
end

# frozen_string_literal: true

Browserctl.workflow "practice_test_automation/login" do
  desc "Login page: fill credentials, verify success, logout"

  param :username,        default: "student"
  param :password,        default: "Password123", secret: true
  param :base_url,        default: "https://practicetestautomation.com"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/practice_test_automation_login.png")

  step "open login page" do
    client.open_page("main", url: "#{base_url}/practice-test-login/")
  end

  step "fill and submit credentials" do
    page(:main).fill("input#username", username)
    page(:main).fill("input#password", password)
    page(:main).click("button#submit")
  end

  step "verify successful login" do
    assert page(:main).url.include?("logged-in-successfully"), "expected redirect to logged-in-successfully"
    heading = client.evaluate("main", "document.querySelector('h1.post-title')?.innerText?.trim()")[:result]
    assert heading == "Logged In Successfully", "expected success heading, got: #{heading.inspect}"
    page(:main).screenshot(path: screenshot_path)
  end

  step "logout and verify" do
    page(:main).click("a.wp-block-button__link")
    assert page(:main).url.include?("practice-test-login"), "expected redirect back to login page"
  end
end

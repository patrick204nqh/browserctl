# frozen_string_literal: true

Browserctl.workflow "practice_test_automation/login_negative" do
  desc "Login page: invalid username and invalid password each show the correct error"

  param :base_url, default: "https://practicetestautomation.com"
  param :screenshot_path,
        default: File.expand_path(".browserctl/screenshots/practice_test_automation_login_negative.png")

  step "open login page" do
    client.open_page("main", url: "#{base_url}/practice-test-login/")
  end

  step "submit invalid username — expect username error" do
    page(:main).fill("input#username", "incorrectUser")
    page(:main).fill("input#password", "Password123")
    page(:main).click("button#submit")
    error = client.evaluate("main", "document.querySelector('#error')?.innerText?.trim()")[:result]
    assert error&.include?("Your username is invalid!"), "expected username error, got: #{error.inspect}"
  end

  step "submit invalid password — expect password error" do
    page(:main).fill("input#username", "student")
    page(:main).fill("input#password", "wrongPassword")
    page(:main).click("button#submit")
    error = client.evaluate("main", "document.querySelector('#error')?.innerText?.trim()")[:result]
    assert error&.include?("Your password is invalid!"), "expected password error, got: #{error.inspect}"
    page(:main).screenshot(path: screenshot_path)
  end
end

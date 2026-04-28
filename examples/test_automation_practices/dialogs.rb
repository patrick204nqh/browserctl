# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/dialogs" do
  desc "Alerts page: pre-register accept/dismiss handlers before triggering each JS dialog type"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/test_automation_practices_dialogs.png")

  step "open alerts page" do
    open_page(:main, url: "#{base_url}/#/alerts")
  end

  step "accept an alert — page stays responsive" do
    page(:main).dialog_accept
    page(:main).click("[data-test='alert-button']")
    sleep 0.3
    result = page(:main).evaluate("1 + 1")
    assert result == 2, "expected page to be responsive after accepting alert"
  end

  step "accept a confirm — page stays responsive" do
    page(:main).dialog_accept
    page(:main).click("[data-test='confirm-button']")
    sleep 0.3
    result = page(:main).evaluate("1 + 1")
    assert result == 2, "expected page to be responsive after accepting confirm"
  end

  step "dismiss a confirm — page stays responsive" do
    page(:main).dialog_dismiss
    page(:main).click("[data-test='confirm-button']")
    sleep 0.3
    result = page(:main).evaluate("1 + 1")
    assert result == 2, "expected page to be responsive after dismissing confirm"
  end

  step "accept a prompt with text — page stays responsive" do
    page(:main).dialog_accept(text: "browserctl")
    page(:main).click("[data-test='prompt-button']")
    sleep 0.3
    result = page(:main).evaluate("1 + 1")
    assert result == 2, "expected page to be responsive after accepting prompt"
    page(:main).screenshot(path: screenshot_path)
  end
end

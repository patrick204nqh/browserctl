# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/dialogs/alerts" do
  desc "Alerts page: pre-register accept/dismiss handlers before triggering each JS dialog type"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/tap_dialogs_alerts.png")

  step "open alerts page" do
    open_page(:main, url: "#{base_url}/#/alerts")
  end

  step "accept an alert — result-container shows confirmation" do
    page(:main).dialog_accept
    page(:main).click("[data-test='alert-button']")
    page(:main).wait("[data-test='result-container']", timeout: 5)
    result = page(:main).evaluate("document.querySelector('[data-test=\"result-container\"]')?.textContent?.trim()")
    assert result == "Last action: Alert shown", "expected alert result, got: #{result.inspect}"
  end

  step "accept a confirm — result-container shows true" do
    page(:main).dialog_accept
    page(:main).click("[data-test='confirm-button']")
    page(:main).wait("[data-test='result-container']", timeout: 5)
    result = page(:main).evaluate("document.querySelector('[data-test=\"result-container\"]')?.textContent?.trim()")
    assert result == "Last action: Confirm dialog: true", "expected confirm true result, got: #{result.inspect}"
  end

  step "dismiss a confirm — result-container shows false" do
    page(:main).dialog_dismiss
    page(:main).click("[data-test='confirm-button']")
    page(:main).wait("[data-test='result-container']", timeout: 5)
    result = page(:main).evaluate("document.querySelector('[data-test=\"result-container\"]')?.textContent?.trim()")
    assert result == "Last action: Confirm dialog: false", "expected confirm false result, got: #{result.inspect}"
  end

  step "accept a prompt with text — result-container shows entered text" do
    page(:main).dialog_accept(text: "browserctl")
    page(:main).click("[data-test='prompt-button']")
    page(:main).wait("[data-test='result-container']", timeout: 5)
    result = page(:main).evaluate("document.querySelector('[data-test=\"result-container\"]')?.textContent?.trim()")
    assert result&.include?("browserctl"), "expected prompt text in result, got: #{result.inspect}"
    page(:main).screenshot(path: screenshot_path)
  end
end

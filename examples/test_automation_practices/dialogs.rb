# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/dialogs" do
  desc "Alerts/dialogs page: pre-register accept/dismiss handlers before triggering each JS dialog"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/test_automation_practices_dialogs.png")

  step "open alerts page" do
    open_page(:main, url: "#{base_url}/#/alerts")
  end

  step "accept an alert dialog" do
    page(:main).dialog_accept
    page(:main).click("[data-test='alert-button']")
    sleep 0.3
    res = client.evaluate("main", "1 + 1")
    assert res[:result] == 2, "expected page to be responsive after accepting alert"
  end

  step "accept a confirm dialog and verify result" do
    page(:main).dialog_accept
    page(:main).click("[data-test='confirm-button']")
    sleep 0.3
    result = client.evaluate("main",
                             "document.querySelector('[data-test=\"dialog-result\"]')?.innerText?.trim()")[:result]
    assert result&.match?(/confirm|true|ok/i), "expected confirm acceptance recorded, got: #{result.inspect}"
  end

  step "dismiss a confirm dialog and verify result" do
    page(:main).dialog_dismiss
    page(:main).click("[data-test='confirm-button']")
    sleep 0.3
    result = client.evaluate("main",
                             "document.querySelector('[data-test=\"dialog-result\"]')?.innerText?.trim()")[:result]
    assert result&.match?(/dismiss|false|cancel/i), "expected confirm dismissal recorded, got: #{result.inspect}"
    page(:main).screenshot(path: screenshot_path)
  end
end

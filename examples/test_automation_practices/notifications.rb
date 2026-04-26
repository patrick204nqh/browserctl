# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/notifications" do
  desc "Notifications: trigger success, error, and info toasts — assert each appears then dismiss"

  param :base_url, default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path,
        default: File.expand_path(".browserctl/screenshots/test_automation_practices_notifications.png")

  step "open notifications page" do
    client.open_page("main", url: "#{base_url}/#/notifications")
  end

  step "trigger success notification and verify" do
    page(:main).click("[data-test='add-success']")
    # notification IDs are dynamic; match any notification element by prefix
    page(:main).wait_for("[data-test^='notification-']", timeout: 5)
    count = client.evaluate(
      "main",
      "document.querySelectorAll('[data-test^=\"notification-\"]').length"
    )[:result]
    assert count >= 1, "expected at least one notification, got: #{count}"
  end

  step "dismiss notification and verify container is empty" do
    page(:main).click("[data-test^='close-notification-']")
    deadline = Time.now + 5
    remaining = nil
    loop do
      remaining = client.evaluate(
        "main",
        "document.querySelectorAll('[data-test^=\"notification-\"]').length"
      )[:result]
      break if remaining.zero? || Time.now > deadline

      sleep 0.2
    end
    assert remaining.zero?, "expected no notifications after dismiss, got: #{remaining}"
  end

  step "trigger error and info notifications together" do
    page(:main).click("[data-test='add-error']")
    page(:main).click("[data-test='add-info']")
    page(:main).wait_for("[data-test^='notification-']", timeout: 5)
    count = client.evaluate(
      "main",
      "document.querySelectorAll('[data-test^=\"notification-\"]').length"
    )[:result]
    assert count == 2, "expected 2 notifications (error + info), got: #{count}"
    page(:main).screenshot(path: screenshot_path)
  end
end

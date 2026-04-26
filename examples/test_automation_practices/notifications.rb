# frozen_string_literal: true

# Individual notification items have data-test="notification-{id}".
# The wrapper has data-test="notification-container" — excluded from counts below.
NOTIFICATION_ITEMS_JS = <<~JS
  document.querySelectorAll('[data-test^="notification-"]:not([data-test="notification-container"])').length
JS

Browserctl.workflow "test_automation_practices/notifications" do
  desc "Notifications: trigger success, error, and info toasts — verify count increases on each trigger"

  param :base_url, default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path,
        default: File.expand_path(".browserctl/screenshots/test_automation_practices_notifications.png")

  step "open notifications page and record baseline" do
    client.open_page("main", url: "#{base_url}/#/notifications")
    page(:main).wait_for("[data-test='notification-container']", timeout: 5)
    # Let any delayed on-load notifications finish appearing before we snapshot the baseline
    sleep 1
    store(:baseline, client.evaluate("main", NOTIFICATION_ITEMS_JS)[:result])
  end

  step "trigger success notification and verify count increased by 1" do
    base = fetch(:baseline)
    page(:main).click("[data-test='add-success']")
    page(:main).wait_for("[data-test^='notification-']:not([data-test='notification-container'])", timeout: 5)
    count = client.evaluate("main", NOTIFICATION_ITEMS_JS)[:result]
    assert count == base + 1, "expected #{base + 1} notifications after success, got: #{count}"
  end

  step "dismiss one notification and verify count returns to baseline" do
    base = fetch(:baseline)
    client.evaluate("main", "document.querySelector('[data-test^=\"close-notification-\"]')?.click()")
    deadline = Time.now + 5
    remaining = nil
    loop do
      remaining = client.evaluate("main", NOTIFICATION_ITEMS_JS)[:result]
      break if remaining <= base || Time.now > deadline

      sleep 0.2
    end
    assert remaining <= base, "expected count back to #{base} after dismiss, got: #{remaining}"
    # Re-snapshot baseline in case on-load notifications auto-dismissed during this step
    store(:baseline, remaining)
  end

  step "trigger error and info notifications and verify count increased by 2" do
    base = fetch(:baseline)
    page(:main).click("[data-test='add-error']")
    page(:main).click("[data-test='add-info']")
    page(:main).wait_for("[data-test^='notification-']:not([data-test='notification-container'])", timeout: 5)
    count = client.evaluate("main", NOTIFICATION_ITEMS_JS)[:result]
    assert count == base + 2, "expected #{base + 2} notifications (error + info), got: #{count}"
    page(:main).screenshot(path: screenshot_path)
  end
end

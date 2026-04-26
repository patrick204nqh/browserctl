# frozen_string_literal: true

# Individual notification items have data-test="notification-{id}".
# The wrapper has data-test="notification-container" — excluded from counts below.
NOTIFICATION_ITEMS_JS = <<~JS
  document.querySelectorAll('[data-test^="notification-"]:not([data-test="notification-container"])').length
JS

Browserctl.workflow "test_automation_practices/notifications" do
  desc "Notifications: trigger success, error, and info toasts — assert each appears then dismiss"

  param :base_url, default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path,
        default: File.expand_path(".browserctl/screenshots/test_automation_practices_notifications.png")

  step "open notifications page" do
    client.open_page("main", url: "#{base_url}/#/notifications")
    # Wait for the container to render before touching anything
    page(:main).wait_for("[data-test='notification-container']", timeout: 5)
    # Dismiss any notifications the app shows on load
    client.evaluate("main", <<~JS)
      document.querySelectorAll('[data-test^="close-notification-"]').forEach(b => b.click())
    JS
    # Poll until clear so counts start at zero before the test steps begin
    deadline = Time.now + 5
    loop do
      break if client.evaluate("main", NOTIFICATION_ITEMS_JS)[:result].zero? || Time.now > deadline

      sleep 0.2
    end
  end

  step "trigger success notification and verify" do
    page(:main).click("[data-test='add-success']")
    page(:main).wait_for("[data-test^='notification-']:not([data-test='notification-container'])", timeout: 5)
    count = client.evaluate("main", NOTIFICATION_ITEMS_JS)[:result]
    assert count == 1, "expected 1 notification, got: #{count}"
  end

  step "dismiss notification and verify none remain" do
    # Use evaluate to click the close button — more reliable than CSS prefix selectors
    client.evaluate("main", "document.querySelector('[data-test^=\"close-notification-\"]')?.click()")
    deadline = Time.now + 5
    remaining = nil
    loop do
      remaining = client.evaluate("main", NOTIFICATION_ITEMS_JS)[:result]
      break if remaining.zero? || Time.now > deadline

      sleep 0.2
    end
    assert remaining.zero?, "expected no notifications after dismiss, got: #{remaining}"
  end

  step "trigger error and info notifications together" do
    page(:main).click("[data-test='add-error']")
    page(:main).click("[data-test='add-info']")
    page(:main).wait_for("[data-test^='notification-']:not([data-test='notification-container'])", timeout: 5)
    count = client.evaluate("main", NOTIFICATION_ITEMS_JS)[:result]
    assert count == 2, "expected 2 notifications (error + info), got: #{count}"
    page(:main).screenshot(path: screenshot_path)
  end
end

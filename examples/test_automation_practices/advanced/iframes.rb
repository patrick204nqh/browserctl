# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/advanced/iframes" do
  desc "Iframes page: click inside sandboxed iframes, verify postMessage received in parent"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/tap_advanced_iframes.png")

  step "open iframes page" do
    open_page(:main, url: "#{base_url}/#/iframes")
    page(:main).wait("[data-test='iframe-container']", timeout: 10)
    sleep 0.5
  end

  step "click button inside iframe1 — message appears in parent" do
    page(:main).evaluate(
      "document.querySelector('[data-test=\"iframe-iframe1\"]').contentDocument.querySelector('button').click()"
    )
    page(:main).wait("[data-test='iframe-message-0']", timeout: 5)
    msg = page(:main).evaluate(
      "document.querySelector('[data-test=\"iframe-message-0\"]')?.textContent?.trim()"
    )
    assert msg&.length&.positive?, "expected a message after clicking iframe1 button, got: #{msg.inspect}"
    page(:main).screenshot(path: screenshot_path)
  end

  step "click button inside iframe2 — second message appears" do
    page(:main).evaluate(
      "document.querySelector('[data-test=\"iframe-iframe2\"]').contentDocument.querySelector('button').click()"
    )
    page(:main).wait("[data-test='iframe-message-1']", timeout: 5)
    count = page(:main).evaluate(
      "document.querySelectorAll('[data-test^=\"iframe-message-\"]').length"
    )
    assert count >= 2, "expected at least 2 messages after both iframe clicks, got: #{count}"
  end
end

# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/advanced/shadow_dom" do
  desc "Shadow DOM page: query inside shadow root, click shadow-button, accept its alert"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/tap_advanced_shadow_dom.png")

  step "open shadow DOM page" do
    open_page(:main, url: "#{base_url}/#/shadow-dom")
    page(:main).wait("[data-test='shadow-host']", timeout: 10)
  end

  step "verify shadow content is accessible via shadowRoot" do
    text = page(:main).evaluate(
      "document.querySelector('[data-test=\"shadow-host\"]').shadowRoot" \
      "?.querySelector('[data-test=\"shadow-content\"]')?.textContent?.trim()"
    )
    assert text&.length&.positive?, "expected shadow-content text via shadowRoot, got: #{text.inspect}"
    page(:main).screenshot(path: screenshot_path)
  end

  step "click shadow-button — accept the alert — page stays responsive" do
    page(:main).dialog_accept
    page(:main).evaluate(
      "document.querySelector('[data-test=\"shadow-host\"]').shadowRoot" \
      ".querySelector('[data-test=\"shadow-button\"]').click()"
    )
    sleep 0.3
    still_present = page(:main).evaluate(
      "!!document.querySelector('[data-test=\"shadow-host\"]')"
    )
    assert still_present, "expected shadow-host to remain in DOM after alert was accepted"
  end
end

# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/key_press" do
  desc "Key press page: dispatch keyboard events, verify last-key display and history list update"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/test_automation_practices_key_press.png")

  step "open key press page" do
    client.open_page("main", url: "#{base_url}/#/key-press")
  end

  step "dispatch key events and verify last-key display" do
    keys = %w[A B C D E]
    keys.each do |key|
      client.evaluate(
        "main",
        "document.dispatchEvent(new KeyboardEvent('keydown', { key: '#{key}', bubbles: true }))"
      )
      sleep 0.1
    end

    last = client.evaluate("main",
                           "document.querySelector('[data-test=\"last-key-pressed\"]')?.innerText?.trim()")[:result]
    assert last == keys.last, "expected last key '#{keys.last}', got: #{last.inspect}"
    store(:keys, keys)
  end

  step "verify key history contains all dispatched keys" do
    keys = fetch(:keys)
    history = client.evaluate(
      "main",
      "Array.from(document.querySelectorAll('[data-test^=\"key-\"]')).map(el => el.innerText?.trim())"
    )[:result]
    # History shows most recent first; each entry typically contains the key label
    keys.each do |key|
      assert history.any? { |entry| entry&.include?(key) }, "expected '#{key}' in history, got: #{history.inspect}"
    end
    page(:main).screenshot(path: screenshot_path)
  end
end

# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/dropdown" do
  desc "Dropdown page: select options by value, verify selection updates the display"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/test_automation_practices_dropdown.png")

  step "open dropdown page" do
    open_page(:main, url: "#{base_url}/#/dropdown")
  end

  step "select first option and verify" do
    page(:main).select("[data-test='dropdown-select']", "option1")
    selected = client.evaluate("main",
                               "document.querySelector('[data-test=\"dropdown-select\"]').value")[:result]
    assert selected == "option1", "expected 'option1', got: #{selected.inspect}"
  end

  step "select second option and verify display updates" do
    page(:main).select("[data-test='dropdown-select']", "option2")
    selected = client.evaluate("main",
                               "document.querySelector('[data-test=\"dropdown-select\"]').value")[:result]
    assert selected == "option2", "expected 'option2', got: #{selected.inspect}"
    page(:main).screenshot(path: screenshot_path)
  end
end

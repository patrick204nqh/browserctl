# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/dynamic/dynamic_elements" do
  desc "Dynamic elements: trigger reload, wait for items, toggle hidden content"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path,
        default: File.expand_path(".browserctl/screenshots/tap_dynamic_dynamic_elements.png")

  step "open dynamic elements page" do
    open_page(:main, url: "#{base_url}/#/dynamic-elements")
  end

  step "assert no dynamic items exist before reload" do
    absent = page(:main).evaluate("!document.querySelector('[data-test=\"dynamic-item-0\"]')")
    assert absent, "expected no dynamic items before triggering reload"
  end

  step "click reload and wait for items" do
    page(:main).click("[data-test='reload-button']")
    # loading indicator appears first; wait for it to clear and items to render
    page(:main).wait("[data-test='dynamic-item-0']", timeout: 15)
  end

  step "verify all three dynamic items are present" do
    count = page(:main).evaluate(
      "[0,1,2].filter(i => !!document.querySelector(`[data-test=\"dynamic-item-${i}\"]`)).length"
    )
    assert count == 3, "expected 3 dynamic items, got: #{count}"
    page(:main).screenshot(path: screenshot_path)
  end

  step "toggle hidden content on" do
    page(:main).click("[data-test='toggle-hidden-button']")
    visible = page(:main).evaluate(
      "!document.querySelector('[data-test=\"hidden-content\"]').classList.contains('hidden')"
    )
    assert visible, "expected hidden-content to become visible after toggle (hidden class should be absent)"
  end
end

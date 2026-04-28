# frozen_string_literal: true

SET_SLIDER_JS = <<~JS
  (function(val) {
    const el = document.querySelector('[data-test="slider"]');
    Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value')
          .set.call(el, val);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  })(%<value>d)
JS

Browserctl.workflow "test_automation_practices/forms/slider" do
  desc "Slider page: set slider to specific values via evaluate, verify displayed value updates"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/tap_forms_slider.png")

  step "open slider page" do
    open_page(:main, url: "#{base_url}/#/slider")
    page(:main).wait("[data-test='slider-container']", timeout: 10)
  end

  step "set slider to 75 and verify display" do
    page(:main).evaluate(format(SET_SLIDER_JS, value: 75))
    sleep 0.1
    displayed = page(:main).evaluate(
      "document.querySelector('[data-test=\"slider-value\"]')?.textContent?.trim()"
    )
    assert displayed&.include?("75"), "expected slider-value to show 75, got: #{displayed.inspect}"
  end

  step "set slider to minimum (0) and verify" do
    page(:main).evaluate(format(SET_SLIDER_JS, value: 0))
    sleep 0.1
    displayed = page(:main).evaluate(
      "document.querySelector('[data-test=\"slider-value\"]')?.textContent?.trim()"
    )
    assert displayed&.include?("0"), "expected slider-value to show 0, got: #{displayed.inspect}"
  end

  step "set slider to maximum (100) and screenshot" do
    page(:main).evaluate(format(SET_SLIDER_JS, value: 100))
    sleep 0.1
    displayed = page(:main).evaluate(
      "document.querySelector('[data-test=\"slider-value\"]')?.textContent?.trim()"
    )
    assert displayed&.include?("100"), "expected slider-value to show 100, got: #{displayed.inspect}"
    page(:main).screenshot(path: screenshot_path)
  end
end

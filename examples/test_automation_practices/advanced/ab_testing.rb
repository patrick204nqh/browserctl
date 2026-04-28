# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/advanced/ab_testing" do
  desc "A/B testing page: verify one variant renders, click counter increments"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/tap_advanced_ab_testing.png")

  step "open A/B testing page and detect variant" do
    open_page(:main, url: "#{base_url}/#/ab-testing")
    page(:main).wait("[data-test='ab-testing-page']", timeout: 10)
    title = page(:main).evaluate(
      "document.querySelector('[data-test=\"variant-title\"]')?.textContent?.trim()"
    )
    assert title&.length&.positive?, "expected variant title to be present, got: #{title.inspect}"
    store(:variant_title, title)
  end

  step "variant title contains A or B" do
    title = fetch(:variant_title)
    assert title.include?("A") || title.include?("B"),
           "expected variant A or B in title, got: #{title.inspect}"
  end

  step "click button — counter increments" do
    initial_text = page(:main).evaluate(
      "document.querySelector('[data-test=\"variant-button\"]')?.textContent?.trim()"
    )
    page(:main).click("[data-test='variant-button']")
    sleep 0.5
    updated_text = page(:main).evaluate(
      "document.querySelector('[data-test=\"variant-button\"]')?.textContent?.trim()"
    )
    assert initial_text != updated_text,
           "expected button text to change after click (counter), still: #{updated_text.inspect}"
    page(:main).screenshot(path: screenshot_path)
  end
end

# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/advanced/broken_images" do
  desc "Broken images page: verify one image loads successfully and two are broken (naturalWidth == 0)"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/tap_advanced_broken_images.png")

  step "open broken images page" do
    open_page(:main, url: "#{base_url}/#/broken-images")
    page(:main).wait("[data-test='image-container-0']", timeout: 10)
    sleep 1
  end

  step "check which images loaded and which are broken" do
    widths = page(:main).evaluate(
      "[0,1,2].map(i => document.querySelector(`[data-test=\"image-${i}\"]`)?.naturalWidth ?? -1)"
    )
    loaded  = widths.count(&:positive?)
    broken  = widths.count(&:zero?)
    assert loaded == 1, "expected exactly 1 valid image, got #{loaded} (widths: #{widths.inspect})"
    assert broken == 2, "expected exactly 2 broken images, got #{broken} (widths: #{widths.inspect})"
    page(:main).screenshot(path: screenshot_path)
  end
end

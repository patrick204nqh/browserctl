# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/hover" do
  desc "Hover states page: move mouse over each figure, verify overlay content appears on each"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/test_automation_practices_hover.png")

  step "open hover states page" do
    open_page(:main, url: "#{base_url}/#/hover")
    page(:main).wait("[data-test='hover-example']", timeout: 10)
  end

  step "hover over each figure and verify caption appears" do
    [1, 2, 3].each do |i|
      page(:main).hover("[data-test='hover-figure-#{i}']")
      sleep 0.2
      caption = client.evaluate(
        "main",
        "!!document.querySelector('[data-test=\"hover-caption-#{i}\"]')"
      )[:result]
      assert caption, "expected caption to appear on figure #{i} after hover"
    end
  end

  step "screenshot the hovered state" do
    page(:main).hover("[data-test='hover-figure-2']")
    sleep 0.2
    page(:main).screenshot(path: screenshot_path)
  end
end

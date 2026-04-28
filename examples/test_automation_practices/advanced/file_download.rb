# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/advanced/file_download" do
  desc "File download page: trigger each download, verify button enters disabled state, verify no error shown"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/tap_advanced_file_download.png")

  step "open file download page" do
    open_page(:main, url: "#{base_url}/#/file-download")
    page(:main).wait("[data-test='download-card-0']", timeout: 10)
  end

  step "click TXT download — button becomes disabled during download" do
    page(:main).click("[data-test='download-button-0']")
    disabled = page(:main).evaluate(
      "document.querySelector('[data-test=\"download-button-0\"]')?.disabled"
    )
    assert disabled, "expected download-button-0 to be disabled while downloading"
    page(:main).wait("[data-test='download-button-0']:not([disabled])", timeout: 10)
    no_error = page(:main).evaluate("!document.querySelector('[data-test=\"error-message\"]')")
    assert no_error, "expected no error-message after TXT download"
  end

  step "click CSV download — completes without error" do
    page(:main).click("[data-test='download-button-1']")
    page(:main).wait("[data-test='download-button-1']:not([disabled])", timeout: 10)
    no_error = page(:main).evaluate("!document.querySelector('[data-test=\"error-message\"]')")
    assert no_error, "expected no error-message after CSV download"
  end

  step "click PDF download — completes without error" do
    page(:main).click("[data-test='download-button-2']")
    page(:main).wait("[data-test='download-button-2']:not([disabled])", timeout: 10)
    no_error = page(:main).evaluate("!document.querySelector('[data-test=\"error-message\"]')")
    assert no_error, "expected no error-message after PDF download"
    page(:main).screenshot(path: screenshot_path)
  end
end

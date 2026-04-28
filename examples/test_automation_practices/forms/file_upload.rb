# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/forms/file_upload" do
  desc "File upload page: attach a local file via the hidden file input, verify the file is selected"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path,
        default: File.expand_path(".browserctl/screenshots/tap_forms_file_upload.png")

  step "open file upload page" do
    open_page(:main, url: "#{base_url}/#/file-upload")
    page(:main).wait("[data-test='file-uploader']", timeout: 10)
  end

  step "upload a file and verify it is selected" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "browserctl_test.txt")
      File.write(path, "browserctl v0.7 upload test")

      page(:main).upload("[data-test='file-input']", path)
      page(:main).wait("[data-test='uploaded-file-0']", timeout: 10)

      filename = page(:main).evaluate(
        "document.querySelector('[data-test=\"uploaded-file-0\"]')?.querySelector('span.truncate')?.textContent?.trim()"
      )
      assert filename == "browserctl_test.txt", "expected filename in list, got: #{filename.inspect}"
    end
    page(:main).screenshot(path: screenshot_path)
  end
end

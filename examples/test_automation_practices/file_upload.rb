# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/file_upload" do
  desc "File upload page: attach a local file to a file input, verify filename appears in the upload preview"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path,
        default: File.expand_path(".browserctl/screenshots/test_automation_practices_file_upload.png")

  step "open file upload page" do
    open_page(:main, url: "#{base_url}/#/file-upload")
  end

  step "upload a file and verify preview" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "browserctl_test.txt")
      File.write(path, "browserctl v0.7 upload test")

      page(:main).upload("[data-test='file-input']", path)

      filename = client.evaluate(
        "main",
        "document.querySelector('[data-test=\"file-input\"]').files[0]?.name"
      )[:result]
      assert filename == "browserctl_test.txt", "expected filename in input, got: #{filename.inspect}"
    end
  end

  step "verify uploaded filename is displayed" do
    displayed = client.evaluate(
      "main",
      "document.querySelector('[data-test=\"uploaded-file\"]')?.innerText?.trim()"
    )[:result]
    assert displayed&.include?("browserctl_test.txt"), "expected filename in display, got: #{displayed.inspect}"
    page(:main).screenshot(path: screenshot_path)
  end
end

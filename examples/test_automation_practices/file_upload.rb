# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/file_upload" do
  desc "File upload page: attach a local file via the hidden file input, verify the file is selected"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path,
        default: File.expand_path(".browserctl/screenshots/test_automation_practices_file_upload.png")

  step "open file upload page" do
    open_page(:main, url: "#{base_url}/#/file-upload")
    page(:main).wait("[data-test='file-uploader']", timeout: 10)
  end

  step "upload a file and verify it is selected" do
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
    page(:main).screenshot(path: screenshot_path)
  end
end

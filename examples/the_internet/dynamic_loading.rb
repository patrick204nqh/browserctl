# frozen_string_literal: true

Browserctl.workflow "the_internet/dynamic_loading" do
  desc "Dynamic loading: click Start, wait for hidden element to appear"

  param :base_url,        default: "https://the-internet.herokuapp.com"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/the_internet_dynamic_loading.png")

  step "open dynamic loading page" do
    open_page(:main, url: "#{base_url}/dynamic_loading/1")
  end

  step "assert finish text is hidden before start" do
    visible = client.evaluate("main", "document.querySelector('#finish').style.display !== 'none'")[:result]
    assert visible == false, "expected #finish to be hidden before start"
  end

  step "click Start and wait for content" do
    page(:main).click("#start button")
    page(:main).wait("#finish h4", timeout: 10)
  end

  step "assert finish text is correct" do
    text = client.evaluate("main", "document.querySelector('#finish h4')?.innerText?.trim()")[:result]
    assert text == "Hello World!", "expected 'Hello World!', got: #{text.inspect}"
    # wait for #loading to disappear before screenshotting so the rendered state is correct
    deadline = Time.now + 5
    sleep 0.2 until client.evaluate("main",
                                    "document.querySelector('#loading')?.style?.display")[:result] == "none" ||
                    Time.now > deadline
    page(:main).screenshot(path: screenshot_path)
  end
end

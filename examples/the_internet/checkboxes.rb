# frozen_string_literal: true

Browserctl.workflow "the_internet/checkboxes" do
  desc "Checkboxes: read state, toggle each, verify both checked"

  param :base_url,        default: "https://the-internet.herokuapp.com"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/the_internet_checkboxes.png")

  step "open checkboxes page" do
    open_page(:main, url: "#{base_url}/checkboxes")
  end

  step "read initial state" do
    js = "Array.from(document.querySelectorAll('input[type=checkbox]')).map(c => c.checked)"
    states = client.evaluate("main", js)[:result]
    assert states == [false, true], "expected initial state [false, true], got: #{states.inspect}"
  end

  step "toggle first checkbox on" do
    page(:main).click("form#checkboxes input:first-child")
    js = "document.querySelector('form#checkboxes input:first-child').checked"
    checked = client.evaluate("main", js)[:result]
    assert checked == true, "expected first checkbox to be checked"
  end

  step "verify both checkboxes are now checked" do
    js = "Array.from(document.querySelectorAll('input[type=checkbox]')).map(c => c.checked)"
    states = client.evaluate("main", js)[:result]
    assert states.all?, "expected both checkboxes checked, got: #{states.inspect}"
  end

  step "capture screenshot" do
    page(:main).screenshot(path: screenshot_path)
  end
end

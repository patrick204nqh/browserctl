# frozen_string_literal: true

Browserctl.workflow "the_internet/dropdown" do
  desc "Dropdown: select each option via JS, assert selected value"

  param :base_url,        default: "https://the-internet.herokuapp.com"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/the_internet_dropdown.png")

  step "open dropdown page" do
    open_page(:main, url: "#{base_url}/dropdown")
  end

  step "assert default is unselected" do
    value = client.evaluate("main", "document.querySelector('select#dropdown').value")[:result]
    assert value == "", "expected empty default, got: #{value.inspect}"
  end

  step "select Option 1" do
    client.evaluate("main", "document.querySelector('select#dropdown').value = '1'")
    selected = client.evaluate("main", "document.querySelector('select#dropdown option:checked').text")[:result]
    assert selected == "Option 1", "expected 'Option 1', got: #{selected.inspect}"
  end

  step "select Option 2" do
    client.evaluate("main", "document.querySelector('select#dropdown').value = '2'")
    selected = client.evaluate("main", "document.querySelector('select#dropdown option:checked').text")[:result]
    assert selected == "Option 2", "expected 'Option 2', got: #{selected.inspect}"
  end

  step "capture screenshot" do
    page(:main).screenshot(path: screenshot_path)
  end
end

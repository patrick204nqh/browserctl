# frozen_string_literal: true

Browserctl.workflow "practice_test_automation/exceptions" do
  desc "Test exceptions: wait for dynamic row, edit disabled field, remove row"

  param :base_url,        default: "https://practicetestautomation.com"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/practice_test_automation_exceptions.png")

  step "open test exceptions page" do
    client.open_page("main", url: "#{base_url}/practice-test-exceptions/")
  end

  step "enable row 1 input and edit it (InvalidElementStateException avoidance)" do
    # Input starts disabled — click Edit to enable it first
    page(:main).click("button#edit_btn")
    page(:main).fill("#row1 input.input-field", "Pasta")
    value = client.evaluate("main", "document.querySelector('#row1 input.input-field').value")[:result]
    assert value == "Pasta", "expected row 1 value 'Pasta', got: #{value.inspect}"
  end

  step "click Add and wait for row 2 to appear (NoSuchElementException avoidance)" do
    page(:main).click("button#add_btn")
    # Row 2 is injected after a 5-second loading delay — watch polls until it appears
    page(:main).watch("#row2", timeout: 10)
    visible = client.evaluate("main", "document.querySelector('#row2')?.style?.display !== 'none'")[:result]
    assert visible, "expected row 2 to be visible after loading"
  end

  step "verify confirmation message" do
    text = client.evaluate("main", "document.querySelector('#confirmation')?.innerText?.trim()")[:result]
    assert text == "Row 2 was added", "expected confirmation 'Row 2 was added', got: #{text.inspect}"
  end

  step "type into row 2 input and save" do
    page(:main).fill("#row2 input.input-field", "Sushi")
    value = client.evaluate("main", "document.querySelector('#row2 input.input-field').value")[:result]
    assert value == "Sushi", "expected row 2 value 'Sushi', got: #{value.inspect}"
    page(:main).click("#row2 button[name='Save']")
    page(:main).screenshot(path: screenshot_path)
  end

  step "remove row 2" do
    page(:main).click("button#remove_btn")
    # Remove hides row 2 (display:none) rather than deleting it from the DOM
    hidden = client.evaluate("main", "document.querySelector('#row2').style.display === 'none'")[:result]
    assert hidden, "expected row 2 to be hidden after removal"
  end
end

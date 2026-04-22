# frozen_string_literal: true

#
# Smoke test for WorkflowContext#store / #fetch (Task 7.3).
#
# Uses the-internet's dynamic loading example: click Start, wait for "Hello World!",
# capture the text in step 1, assert it is still accessible in step 2 via fetch.

Browserctl.workflow "smoke/store_fetch" do
  desc "Smoke: store a value in one step and retrieve it in a later step"

  param :base_url, default: "https://the-internet.herokuapp.com"

  step "open dynamic loading page" do
    client.open_page("main", url: "#{base_url}/dynamic_loading/1")
  end

  step "click start and capture loaded text" do
    page(:main).click("div#start button")
    page(:main).wait_for("div#finish", timeout: 10)
    text = client.evaluate("main", "document.querySelector('div#finish h4')?.innerText?.trim()")[:result]
    assert text && !text.empty?, "expected loaded text, got: #{text.inspect}"
    store(:loaded_text, text)
    puts "  [store] loaded_text = #{text.inspect}"
  end

  step "fetch value from previous step and assert" do
    text = fetch(:loaded_text)
    puts "  [fetch] loaded_text = #{text.inspect}"
    assert text == "Hello World!", "expected 'Hello World!', got: #{text.inspect}"
  end

  step "confirm fetch raises for unknown key" do
    fetch(:nonexistent_key)
    assert false, "expected KeyError was not raised"
  rescue KeyError => e
    puts "  [ok] KeyError raised as expected: #{e.message}"
  end
end

Browserctl.workflow "the_internet/checkboxes" do
  desc "Checkboxes: read state, toggle each, verify both checked"

  param :base_url, default: "https://the-internet.herokuapp.com"

  step "open checkboxes page" do
    client.open_page("main", url: "#{base_url}/checkboxes")
  end

  step "read initial state" do
    states = client.evaluate("main", "Array.from(document.querySelectorAll('input[type=checkbox]')).map(c => c.checked)")[:result]
    assert states == [false, true], "expected initial state [false, true], got: #{states.inspect}"
  end

  step "toggle first checkbox on" do
    page(:main).click("form#checkboxes input:first-child")
    checked = client.evaluate("main", "document.querySelector('form#checkboxes input:first-child').checked")[:result]
    assert checked == true, "expected first checkbox to be checked"
  end

  step "verify both checkboxes are now checked" do
    states = client.evaluate("main", "Array.from(document.querySelectorAll('input[type=checkbox]')).map(c => c.checked)")[:result]
    assert states.all?, "expected both checkboxes checked, got: #{states.inspect}"
  end
end

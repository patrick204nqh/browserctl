Browserctl.workflow "the_internet/add_remove_elements" do
  desc "Add/Remove Elements: add several elements, remove some, assert final count"

  param :base_url, default: "https://the-internet.herokuapp.com"

  step "open add/remove elements page" do
    client.open_page("main", url: "#{base_url}/add_remove_elements/")
  end

  step "add three elements" do
    3.times { page(:main).click("button[onclick]") }
    count = client.evaluate("main", "document.querySelectorAll('#elements button').length")[:result]
    assert count == 3, "expected 3 elements, got: #{count}"
  end

  step "remove one element" do
    page(:main).click("#elements button:first-child")
    count = client.evaluate("main", "document.querySelectorAll('#elements button').length")[:result]
    assert count == 2, "expected 2 elements after removal, got: #{count}"
  end

  step "remove all remaining elements" do
    2.times { page(:main).click("#elements button:first-child") }
    count = client.evaluate("main", "document.querySelectorAll('#elements button').length")[:result]
    assert count == 0, "expected 0 elements, got: #{count}"
  end
end

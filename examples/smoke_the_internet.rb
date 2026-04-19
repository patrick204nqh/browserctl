Browserctl.workflow "smoke_the_internet" do
  desc "Smoke test against the-internet.herokuapp.com: login + checkbox interaction"

  param :username, default: "tomsmith"
  param :password, default: "SuperSecretPassword!", secret: true
  param :base_url, default: "https://the-internet.herokuapp.com"

  step "open login page" do
    client.open_page("main", url: "#{base_url}/login")
  end

  step "fill and submit credentials" do
    page(:main).fill("input#username", username)
    page(:main).fill("input#password", password)
    page(:main).click("button[type=submit]")
  end

  step "verify login succeeded" do
    assert page(:main).url.include?("/secure"), "expected redirect to /secure"
    flash = client.evaluate("main", "document.querySelector('.flash.success')?.innerText?.trim()")[:result]
    assert flash&.include?("You logged into a secure area!"), "expected success flash, got: #{flash.inspect}"
  end

  step "navigate to checkboxes" do
    page(:main).goto("#{base_url}/checkboxes")
  end

  step "toggle first checkbox and verify" do
    before = client.evaluate("main", "document.querySelector('form#checkboxes input').checked")[:result]
    page(:main).click("form#checkboxes input:first-child")
    after = client.evaluate("main", "document.querySelector('form#checkboxes input').checked")[:result]
    assert after == !before, "expected checkbox to toggle from #{before} to #{!before}, got #{after}"
  end
end

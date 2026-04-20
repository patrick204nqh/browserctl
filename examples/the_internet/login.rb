# frozen_string_literal: true

Browserctl.workflow "the_internet/login" do
  desc "Form authentication: fill credentials, submit, assert secure area"

  param :username,        default: "tomsmith"
  param :password,        default: "SuperSecretPassword!", secret: true
  param :base_url,        default: "https://the-internet.herokuapp.com"
  param :screenshot_path, default: File.expand_path("~/.browserctl/screenshots/the_internet_login.png")

  step "open login page" do
    client.open_page("main", url: "#{base_url}/login")
  end

  step "fill and submit credentials" do
    page(:main).fill("input#username", username)
    page(:main).fill("input#password", password)
    page(:main).click("button[type=submit]")
  end

  step "verify secure area" do
    assert page(:main).url.include?("/secure"), "expected redirect to /secure"
    flash = client.evaluate("main", "document.querySelector('.flash.success')?.innerText?.trim()")[:result]
    assert flash&.include?("You logged into a secure area!"), "expected success flash, got: #{flash.inspect}"
    page(:main).screenshot(path: screenshot_path)
  end

  step "logout and verify" do
    page(:main).click("a[href='/logout']")
    flash = client.evaluate("main", "document.querySelector('.flash.success')?.innerText?.trim()")[:result]
    assert flash&.include?("You logged out"), "expected logout flash, got: #{flash.inspect}"
  end
end

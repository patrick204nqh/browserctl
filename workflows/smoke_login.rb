Browserctl.workflow "smoke_login" do
  desc "Log in and confirm the dashboard loads"

  param :email,    required: true
  param :password, required: true,  secret: true
  param :base_url, default: "https://app.example.com"

  step "open login page" do
    page(:login).goto("#{base_url}/login")
  end

  step "submit credentials" do
    page(:login).fill("input[name=email]",    email)
    page(:login).fill("input[name=password]", password)
    page(:login).click("button[type=submit]")
  end

  step "verify dashboard" do
    page(:login).wait_for("[data-test=dashboard]", timeout: 10)
    assert page(:login).url.include?("/dashboard"), "expected /dashboard in URL"
  end
end

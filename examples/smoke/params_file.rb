# frozen_string_literal: true

#
# Smoke test for --params file loading (Task 7.5).
#
# Run with:
#   browserctl workflow run examples/smoke/params_file.rb --params examples/smoke/params_file.yml
#
# The workflow logs in using credentials from the params file and asserts
# the secure area is reached — proving the params were loaded and available.

Browserctl.workflow "smoke/params_file" do
  desc "Smoke: load credentials from a --params file and use them in a workflow"

  param :username, required: true
  param :password, required: true, secret: true
  param :base_url, default: "https://the-internet.herokuapp.com"

  step "open login page" do
    open_page(:main, url: "#{base_url}/login")
  end

  step "fill credentials from params file" do
    puts "  [params] username = #{username.inspect}"
    puts "  [params] password = (#{password.length} chars, secret)"
    page(:main).fill("input#username", username)
    page(:main).fill("input#password", password)
    page(:main).click("button[type=submit]")
  end

  step "assert login succeeded" do
    assert page(:main).url.include?("/secure"), "expected redirect to /secure — params may not have loaded"
    puts "  [ok] reached secure area — params file loaded correctly"
  end
end

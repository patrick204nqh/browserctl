# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/checkboxes" do
  desc "Checkboxes: toggle individual, check all, uncheck all — assert state each time"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/test_automation_practices_checkboxes.png")

  step "open checkboxes page" do
    client.open_page("main", url: "#{base_url}/#/checkboxes")
  end

  step "read initial state — all unchecked" do
    js = "[1,2,3].map(i => document.querySelector(`[data-test=\"checkbox-checkbox${i}\"]`)?.checked)"
    states = client.evaluate("main", js)[:result]
    assert states.none?, "expected all unchecked initially, got: #{states.inspect}"
  end

  step "toggle checkbox 1 on" do
    page(:main).click("[data-test='checkbox-checkbox1']")
    checked = client.evaluate("main", "document.querySelector('[data-test=\"checkbox-checkbox1\"]').checked")[:result]
    assert checked, "expected checkbox 1 to be checked after click"
  end

  step "check all and verify" do
    page(:main).click("[data-test='check-all-button']")
    js = "[1,2,3].map(i => document.querySelector(`[data-test=\"checkbox-checkbox${i}\"]`)?.checked)"
    states = client.evaluate("main", js)[:result]
    assert states.all?, "expected all checkboxes checked, got: #{states.inspect}"
    page(:main).screenshot(path: screenshot_path)
  end

  step "uncheck all and verify" do
    page(:main).click("[data-test='uncheck-all-button']")
    js = "[1,2,3].map(i => document.querySelector(`[data-test=\"checkbox-checkbox${i}\"]`)?.checked)"
    states = client.evaluate("main", js)[:result]
    assert states.none?, "expected all checkboxes unchecked, got: #{states.inspect}"
  end
end

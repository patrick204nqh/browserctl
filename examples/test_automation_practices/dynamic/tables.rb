# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/dynamic/tables" do
  desc "Tables page: verify initial data, sort by column ascending and descending"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/tap_dynamic_tables.png")

  step "open tables page and verify initial rows" do
    open_page(:main, url: "#{base_url}/#/tables")
    page(:main).wait("[data-test='dynamic-table']", timeout: 10)
    rows = page(:main).evaluate(
      "Array.from(document.querySelectorAll('[data-test^=\"table-row-\"]')).map(r => r.dataset.test)"
    )
    assert rows.length == 3, "expected 3 rows, got: #{rows.length}"
  end

  step "sort by name ascending — alphabetical order" do
    page(:main).click("[data-test='table-header-name']")
    sleep 0.2
    names = page(:main).evaluate(
      "Array.from(document.querySelectorAll('[data-test^=\"table-cell-name-\"]')).map(el => el.textContent?.trim())"
    )
    sorted = names.sort
    assert names == sorted, "expected names sorted ascending, got: #{names.inspect}"
    page(:main).screenshot(path: screenshot_path)
  end

  step "sort by name descending — click header again" do
    page(:main).click("[data-test='table-header-name']")
    sleep 0.2
    names = page(:main).evaluate(
      "Array.from(document.querySelectorAll('[data-test^=\"table-cell-name-\"]')).map(el => el.textContent?.trim())"
    )
    sorted_desc = names.sort.reverse
    assert names == sorted_desc, "expected names sorted descending, got: #{names.inspect}"
  end

  step "sort by status — Active/Inactive grouping" do
    page(:main).click("[data-test='table-header-status']")
    sleep 0.2
    statuses = page(:main).evaluate(
      "Array.from(document.querySelectorAll('[data-test^=\"table-cell-status-\"]')).map(el => el.textContent?.trim())"
    )
    assert statuses == statuses.sort, "expected statuses sorted ascending, got: #{statuses.inspect}"
  end
end

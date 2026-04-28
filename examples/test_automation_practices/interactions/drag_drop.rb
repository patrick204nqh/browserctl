# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/interactions/drag_drop" do
  desc "Drag-drop page: reorder items via keyboard (Space to pick up, Arrow to move, Space to drop)"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/tap_interactions_drag_drop.png")

  step "open drag-drop page and read initial order" do
    open_page(:main, url: "#{base_url}/#/drag-drop")
    page(:main).wait("[data-test='drag-drop-list']", timeout: 10)
    items = page(:main).evaluate(
      "Array.from(document.querySelectorAll('[data-test=\"drag-drop-list\"] li')).map(el => el.textContent?.trim())"
    )
    store(:initial_order, items)
    assert items.length == 5, "expected 5 items in drag-drop list, got: #{items.length}"
  end

  step "focus first item and move it down one position via keyboard" do
    page(:main).evaluate(
      "document.querySelectorAll('[data-test=\"drag-drop-list\"] li')[0].focus()"
    )
    sleep 0.1
    page(:main).press("Space")
    sleep 0.1
    page(:main).press("ArrowDown")
    sleep 0.1
    page(:main).press("Space")
    sleep 0.2
  end

  step "verify first item moved to second position" do
    initial = fetch(:initial_order)
    current = page(:main).evaluate(
      "Array.from(document.querySelectorAll('[data-test=\"drag-drop-list\"] li')).map(el => el.textContent?.trim())"
    )
    assert current[1] == initial[0],
           "expected '#{initial[0]}' at index 1 after move down, got order: #{current.inspect}"
    page(:main).screenshot(path: screenshot_path)
  end
end

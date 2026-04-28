# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/interactions/context_menu" do
  desc "Context menu page: trigger via dispatched contextmenu event, click each action, dismiss"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/tap_interactions_context_menu.png")

  step "open context menu page" do
    open_page(:main, url: "#{base_url}/#/context-menu")
    page(:main).wait("[data-test='context-menu-trigger']", timeout: 10)
  end

  step "trigger context menu via dispatched event — menu appears" do
    page(:main).evaluate(<<~JS)
      document.querySelector('[data-test="context-menu-trigger"]').dispatchEvent(
        new MouseEvent('contextmenu', { bubbles: true, cancelable: true, clientX: 200, clientY: 300 })
      )
    JS
    page(:main).wait("[data-test='context-menu']", timeout: 5)
    visible = page(:main).evaluate("!!document.querySelector('[data-test=\"context-menu\"]')")
    assert visible, "expected context-menu to appear after right-click event"
  end

  step "all three menu items are present" do
    has_edit       = page(:main).evaluate("!!document.querySelector('[data-test=\"context-menu-edit\"]')")
    has_delete     = page(:main).evaluate("!!document.querySelector('[data-test=\"context-menu-delete\"]')")
    has_properties = page(:main).evaluate("!!document.querySelector('[data-test=\"context-menu-properties\"]')")
    assert has_edit,       "expected context-menu-edit to be present"
    assert has_delete,     "expected context-menu-delete to be present"
    assert has_properties, "expected context-menu-properties to be present"
    page(:main).screenshot(path: screenshot_path)
  end

  step "click Edit — menu closes" do
    page(:main).click("[data-test='context-menu-edit']")
    sleep 0.2
    gone = page(:main).evaluate("!document.querySelector('[data-test=\"context-menu\"]')")
    assert gone, "expected context-menu to close after clicking Edit"
  end

  step "re-open and dismiss by clicking outside" do
    page(:main).evaluate(<<~JS)
      document.querySelector('[data-test="context-menu-trigger"]').dispatchEvent(
        new MouseEvent('contextmenu', { bubbles: true, cancelable: true, clientX: 200, clientY: 300 })
      )
    JS
    page(:main).wait("[data-test='context-menu']", timeout: 5)
    page(:main).evaluate("document.querySelector('[data-test=\"context-menu-area\"]').click()")
    sleep 0.2
    gone = page(:main).evaluate("!document.querySelector('[data-test=\"context-menu\"]')")
    assert gone, "expected context-menu to close after clicking outside"
  end
end

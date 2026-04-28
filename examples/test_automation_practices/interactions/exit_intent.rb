# frozen_string_literal: true

Browserctl.workflow "test_automation_practices/interactions/exit_intent" do
  desc "Exit intent page: trigger modal by dispatching mouseleave at viewport top, test all dismiss paths"

  param :base_url,        default: "https://moatazeldebsy.github.io/test-automation-practices"
  param :screenshot_path, default: File.expand_path(".browserctl/screenshots/tap_interactions_exit_intent.png")

  step "open exit intent page" do
    open_page(:main, url: "#{base_url}/#/exit-intent")
    sleep 0.5
  end

  step "trigger exit intent — modal appears" do
    page(:main).evaluate(<<~JS)
      document.dispatchEvent(
        new MouseEvent('mouseleave', { bubbles: true, cancelable: true, clientY: -1 })
      )
    JS
    page(:main).wait("[data-test='exit-modal']", timeout: 5)
    visible = page(:main).evaluate("!!document.querySelector('[data-test=\"exit-modal\"]')")
    assert visible, "expected exit-modal to appear after mouseleave event"
    page(:main).screenshot(path: screenshot_path)
  end

  step "dismiss via X close button — modal disappears" do
    page(:main).click("[data-test='close-modal']")
    sleep 0.2
    gone = page(:main).evaluate("!document.querySelector('[data-test=\"exit-modal\"]')")
    assert gone, "expected exit-modal to close after clicking X"
  end

  step "re-trigger and dismiss via No thanks" do
    page(:main).navigate("#{base_url}/#/exit-intent")
    sleep 0.5
    page(:main).evaluate(<<~JS)
      document.dispatchEvent(
        new MouseEvent('mouseleave', { bubbles: true, cancelable: true, clientY: -1 })
      )
    JS
    page(:main).wait("[data-test='exit-modal']", timeout: 5)
    page(:main).click("[data-test='modal-no']")
    sleep 0.2
    gone = page(:main).evaluate("!document.querySelector('[data-test=\"exit-modal\"]')")
    assert gone, "expected exit-modal to close after clicking No thanks"
  end
end

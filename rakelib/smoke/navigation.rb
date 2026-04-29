# frozen_string_literal: true

#
# Smoke test: page lifecycle + navigation + wait.
#
# Covers: page open, page list, page close, navigate, url, wait (present
# and absent selectors). Uses only data: URIs — no network required.
#
# Run with:
#   browserctl workflow run examples/smoke/navigation.rb

require "base64"

NAV_PAGE_HTML = Base64.strict_encode64(<<~HTML)
  <html><body>
    <h1 id="heading">Smoke nav</h1>
    <a id="link" href="#">link</a>
  </body></html>
HTML
NAV_PAGE_URL = "data:text/html;base64,#{NAV_PAGE_HTML}".freeze

Browserctl.workflow "smoke/navigation" do
  desc "Smoke: page lifecycle, navigate, url, wait"

  step "open named page" do
    open_page(:nav, url: NAV_PAGE_URL)
    puts "  [ok] page :nav opened"
  end

  step "page list includes the open page" do
    pages = client.page_list[:pages]
    assert pages.include?("nav"), "expected 'nav' in page list, got: #{pages.inspect}"
    puts "  [ok] page list: #{pages.inspect}"
  end

  step "url returns current location" do
    current = page(:nav).url
    assert current.start_with?("data:"), "expected data: URL, got: #{current.inspect}"
    puts "  [ok] url: #{current[0, 40]}..."
  end

  step "navigate to about:blank" do
    page(:nav).navigate("about:blank")
    current = page(:nav).url
    assert current == "about:blank", "expected about:blank, got: #{current.inspect}"
    puts "  [ok] navigated to about:blank"
  end

  step "navigate back to page with elements" do
    page(:nav).navigate(NAV_PAGE_URL)
    puts "  [ok] navigated back to element page"
  end

  step "wait succeeds for a present selector" do
    page(:nav).wait("#heading", timeout: 5)
    puts "  [ok] wait succeeded for #heading"
  end

  step "wait raises for an absent selector" do
    page(:nav).wait(".this-element-does-not-exist-smoke", timeout: 1)
    assert false, "expected WorkflowError was not raised"
  rescue Browserctl::WorkflowError => e
    puts "  [ok] wait correctly timed out: #{e.message}"
  end

  step "open a second page" do
    open_page(:nav2, url: "about:blank")
    pages = client.page_list[:pages]
    assert pages.include?("nav2"), "expected :nav2 in page list"
    puts "  [ok] second page :nav2 opened"
  end

  step "close pages" do
    close_page(:nav)
    close_page(:nav2)
    pages = client.page_list[:pages]
    assert !pages.include?("nav"),  "expected :nav closed"
    assert !pages.include?("nav2"), "expected :nav2 closed"
    puts "  [ok] both pages closed"
  end
end

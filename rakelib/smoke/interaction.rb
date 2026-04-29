# frozen_string_literal: true

#
# Smoke test: fill, click, press, hover, select.
#
# Covers all discrete interaction commands from the skill. Uses a data: URI
# page so no network is required.
#
# Run with:
#   browserctl workflow run examples/smoke/interaction.rb

require "base64"

INT_HTML = Base64.strict_encode64(<<~HTML)
  <html><body>
    <input id="name"    type="text"  value="old">
    <input id="email"   type="email" value="">
    <select id="lang">
      <option value="ruby">Ruby</option>
      <option value="go">Go</option>
      <option value="python">Python</option>
    </select>
    <div id="hover-target"
         style="width:80px;height:40px;position:absolute;top:120px;left:120px"
         onmouseenter="this.dataset.hovered='yes'">hover me</div>
    <button id="btn" onclick="this.dataset.clicked=(parseInt(this.dataset.clicked||0)+1)+''" >Click</button>
    <input id="press-target" type="text" onkeydown="this.dataset.lastkey=event.key">
  </body></html>
HTML
INT_URL = "data:text/html;base64,#{INT_HTML}".freeze

Browserctl.workflow "smoke/interaction" do
  desc "Smoke: fill, click, press, hover, select"

  step "setup" do
    open_page(:int, url: INT_URL)
  end

  step "fill — replaces existing value" do
    page(:int).fill("input#name", "replacement")
    value = page(:int).evaluate("document.getElementById('name').value")
    assert value == "replacement", "expected 'replacement', got: #{value.inspect}"
    puts "  [ok] fill: value = #{value.inspect}"
  end

  step "fill — sets empty field" do
    page(:int).fill("input#email", "smoke@example.com")
    value = page(:int).evaluate("document.getElementById('email').value")
    assert value == "smoke@example.com", "expected email, got: #{value.inspect}"
    puts "  [ok] fill email: #{value.inspect}"
  end

  step "click — triggers onclick handler" do
    page(:int).click("button#btn")
    page(:int).click("button#btn")
    count = page(:int).evaluate("document.getElementById('btn').dataset.clicked")
    assert count == "2", "expected click count '2', got: #{count.inspect}"
    puts "  [ok] click: count = #{count}"
  end

  step "press — fires key events" do
    page(:int).evaluate("document.getElementById('press-target').focus()")
    page(:int).press("Tab")
    puts "  [ok] press Tab fired (focus moved)"
  end

  step "press — Enter key" do
    page(:int).evaluate("document.getElementById('press-target').focus()")
    page(:int).press("Enter")
    puts "  [ok] press Enter fired"
  end

  step "hover — moves mouse to element" do
    page(:int).hover("#hover-target")
    puts "  [ok] hover succeeded (no error)"
  end

  step "select — changes selected option" do
    page(:int).select("select#lang", "go")
    value = page(:int).evaluate("document.getElementById('lang').value")
    assert value == "go", "expected 'go', got: #{value.inspect}"
    puts "  [ok] select: value = #{value.inspect}"
  end

  step "select — another option" do
    page(:int).select("select#lang", "python")
    value = page(:int).evaluate("document.getElementById('lang').value")
    assert value == "python", "expected 'python', got: #{value.inspect}"
    puts "  [ok] select again: value = #{value.inspect}"
  end

  step "fill raises for unknown selector" do
    page(:int).fill("input#does-not-exist-smoke", "value")
    assert false, "expected WorkflowError was not raised"
  rescue Browserctl::WorkflowError => e
    puts "  [ok] fill unknown selector raised: #{e.message}"
  end

  step "click raises for unknown selector" do
    page(:int).click("button#does-not-exist-smoke")
    assert false, "expected WorkflowError was not raised"
  rescue Browserctl::WorkflowError => e
    puts "  [ok] click unknown selector raised: #{e.message}"
  end

  step "teardown" do
    close_page(:int)
  end
end

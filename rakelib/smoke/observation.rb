# frozen_string_literal: true

#
# Smoke test: snapshot (elements, html, diff), screenshot, evaluate.
#
# Covers every observation command from the skill. Uses a data: URI page
# so no network is required.
#
# Run with:
#   browserctl workflow run examples/smoke/observation.rb

require "base64"

OBS_HTML = Base64.strict_encode64(<<~HTML)
  <html><body>
    <input id="name" type="text" placeholder="Name">
    <button id="submit">Submit</button>
    <a id="link" href="#">Link</a>
  </body></html>
HTML
OBS_URL = "data:text/html;base64,#{OBS_HTML}".freeze

Browserctl.workflow "smoke/observation" do
  desc "Smoke: snapshot (elements, html, diff), screenshot, evaluate"

  step "setup" do
    open_page(:obs, url: OBS_URL)
  end

  step "snapshot elements — returns ref array" do
    result = page(:obs).snapshot
    elements = result[:snapshot]
    assert elements.is_a?(Array), "expected snapshot to be an Array, got: #{elements.class}"
    assert elements.length.positive?, "expected at least one element"
    assert elements.all? { |e| e[:ref] }, "expected every element to have a :ref"
    assert elements.all? { |e| e[:tag] }, "expected every element to have a :tag"
    puts "  [ok] #{elements.length} elements — refs: #{elements.map { |e| e[:ref] }.join(', ')}"
  end

  step "snapshot selectors are usable for interactions" do
    result = page(:obs).snapshot
    input = result[:snapshot].find { |e| e[:tag] == "input" }
    assert input, "expected an <input> in the snapshot"
    assert input[:selector], "expected input to have a :selector"
    puts "  [ok] input selector: #{input[:selector].inspect}"
  end

  step "snapshot --ref fill — ref-based interaction" do
    result = page(:obs).snapshot
    input = result[:snapshot].find { |e| e[:tag] == "input" }
    assert input, "no input ref found in snapshot"
    ref = input[:ref]
    res = client.fill("obs", nil, "ref-filled", ref: ref)
    assert !res[:error], "fill by ref failed: #{res[:error]}"
    value = page(:obs).evaluate("document.getElementById('name').value")
    assert value == "ref-filled", "expected 'ref-filled', got: #{value.inspect}"
    puts "  [ok] ref-based fill (#{ref}) → value verified"
  end

  step "snapshot --diff after interaction" do
    page(:obs).fill("input#name", "changed")
    diff = page(:obs).snapshot(diff: true)
    elements = diff[:snapshot]
    assert elements.is_a?(Array), "expected snapshot diff to return an Array"
    puts "  [ok] snapshot --diff returned #{elements.length} changed element(s)"
  end

  step "snapshot html format" do
    result = page(:obs).snapshot(format: "html")
    html = result[:html]
    assert html.is_a?(String) && html.include?("<"), "expected HTML string, got: #{html.inspect[0, 80]}"
    puts "  [ok] snapshot html (#{html.length} chars)"
  end

  step "screenshot" do
    result = page(:obs).screenshot
    assert result[:ok], "expected screenshot to succeed"
    puts "  [ok] screenshot → #{result[:path]}"
  end

  step "evaluate — JS expression returns expected value" do
    result = page(:obs).evaluate("1 + 2")
    assert result == 3, "expected 3, got: #{result.inspect}"
    puts "  [ok] evaluate: 1 + 2 = #{result}"
  end

  step "evaluate — DOM query" do
    value = page(:obs).evaluate("document.getElementById('submit').textContent.trim()")
    assert value == "Submit", "expected 'Submit', got: #{value.inspect}"
    puts "  [ok] evaluate DOM: button text = #{value.inspect}"
  end

  step "teardown" do
    close_page(:obs)
  end
end

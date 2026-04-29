# frozen_string_literal: true

#
# Smoke test: upload, dialog accept / dismiss / prompt.
#
# Covers the upload and dialog primitives from the skill. Uses a data: URI
# page so no network is required. The upload test uses this workflow file
# itself as the file to upload (always present on disk).
#
# Run with:
#   browserctl workflow run examples/smoke/upload_dialog.rb

require "base64"

DIALOG_HTML = Base64.strict_encode64(<<~HTML)
  <html><body>
    <input id="file-input" type="file">
    <button id="alert-btn"   onclick="alert('hello smoke')">Alert</button>
    <button id="confirm-btn" onclick="window.confirmed=confirm('continue?')">Confirm</button>
    <button id="dismiss-btn" onclick="window.dismissed=confirm('cancel?')">Dismiss</button>
    <button id="prompt-btn"  onclick="window.prompted=prompt('enter value:')">Prompt</button>
  </body></html>
HTML
DIALOG_URL = "data:text/html;base64,#{DIALOG_HTML}".freeze

Browserctl.workflow "smoke/upload_dialog" do
  desc "Smoke: upload file input, dialog accept/dismiss/prompt"

  step "setup" do
    open_page(:dlg, url: DIALOG_URL)
  end

  step "upload — sets file input to an existing file" do
    # Use this workflow file itself as the upload target — always present.
    path = File.expand_path(__FILE__)
    page(:dlg).upload("#file-input", path)
    name = page(:dlg).evaluate("document.getElementById('file-input').files[0]?.name")
    assert name == File.basename(path), "expected filename #{File.basename(path).inspect}, got: #{name.inspect}"
    puts "  [ok] upload: file name = #{name.inspect}"
  end

  step "upload — raises for missing file" do
    page(:dlg).upload("#file-input", "/tmp/nonexistent_smoke_file_xyz_abc.txt")
    assert false, "expected WorkflowError was not raised"
  rescue Browserctl::WorkflowError => e
    puts "  [ok] upload missing file raised: #{e.message}"
  end

  step "dialog accept — dismisses alert without hanging" do
    page(:dlg).dialog_accept
    page(:dlg).evaluate("document.getElementById('alert-btn').click()")
    sleep 0.3
    # If the dialog wasn't handled the page would hang; verify it's still alive.
    result = page(:dlg).evaluate("1 + 1")
    assert result == 2, "page unresponsive after alert — dialog may not have been accepted"
    puts "  [ok] alert accepted, page still responsive"
  end

  step "dialog accept — confirm returns true" do
    page(:dlg).dialog_accept
    page(:dlg).evaluate("document.getElementById('confirm-btn').click()")
    sleep 0.3
    confirmed = page(:dlg).evaluate("window.confirmed")
    assert confirmed == true, "expected window.confirmed = true, got: #{confirmed.inspect}"
    puts "  [ok] confirm accepted → window.confirmed = #{confirmed}"
  end

  step "dialog dismiss — confirm returns false" do
    page(:dlg).dialog_dismiss
    page(:dlg).evaluate("document.getElementById('dismiss-btn').click()")
    sleep 0.3
    dismissed = page(:dlg).evaluate("window.dismissed")
    assert dismissed == false, "expected window.dismissed = false, got: #{dismissed.inspect}"
    puts "  [ok] confirm dismissed → window.dismissed = #{dismissed}"
  end

  step "dialog accept with text — prompt returns supplied value" do
    page(:dlg).dialog_accept(text: "smoke-answer")
    page(:dlg).evaluate("document.getElementById('prompt-btn').click()")
    sleep 0.3
    prompted = page(:dlg).evaluate("window.prompted")
    assert prompted == "smoke-answer", "expected 'smoke-answer', got: #{prompted.inspect}"
    puts "  [ok] prompt answered → window.prompted = #{prompted.inspect}"
  end

  step "teardown" do
    close_page(:dlg)
  end
end

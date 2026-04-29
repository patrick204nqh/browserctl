# frozen_string_literal: true

#
# Smoke test: session save, list, load, delete.
#
# Verifies the full session lifecycle. Opens a page, sets some state, saves
# it to a named session, closes the page, and loads the session back to
# confirm the page is restored. Navigates to https://example.com because
# session_save reads localStorage and Chrome denies that on about:blank.
#
# Run with:
#   browserctl workflow run examples/smoke/session.rb

SESSION_NAME = "smoke-session-#{Process.pid}".freeze

Browserctl.workflow "smoke/session" do
  desc "Smoke: session save, list, load, delete"

  step "setup — open page with state" do
    open_page(:sess, url: "https://example.com")
    puts "  [ok] page :sess opened"
  end

  step "session save" do
    save_session(SESSION_NAME)
    puts "  [ok] session saved as #{SESSION_NAME.inspect}"
  end

  step "session list — contains saved session" do
    sessions = list_sessions
    names = sessions.map { |s| s[:name] }
    assert names.include?(SESSION_NAME),
           "expected #{SESSION_NAME.inspect} in session list, got: #{names.inspect}"
    puts "  [ok] session list: #{names.inspect}"
  end

  step "close page before loading session" do
    close_page(:sess)
    pages = client.page_list[:pages]
    assert !pages.include?("sess"), "expected :sess closed"
    puts "  [ok] page :sess closed"
  end

  step "session load — restores page" do
    load_session(SESSION_NAME)
    pages = client.page_list[:pages]
    assert pages.include?("sess"), "expected :sess restored by session load, got: #{pages.inspect}"
    puts "  [ok] session loaded — pages: #{pages.inspect}"
  end

  step "session delete" do
    client.session_delete(SESSION_NAME)
    sessions = list_sessions
    names = sessions.map { |s| s[:name] }
    assert !names.include?(SESSION_NAME),
           "expected #{SESSION_NAME.inspect} deleted, still in: #{names.inspect}"
    puts "  [ok] session deleted"
  end

  step "teardown" do
    client.page_close("sess")
  rescue StandardError
    nil
  end
end

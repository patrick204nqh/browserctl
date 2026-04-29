# frozen_string_literal: true

#
# Smoke test: encrypted session save/load/delete.
#
# Verifies that `save_session(name, encrypt: true)` writes .enc files and
# that a subsequent load restores the page correctly. Requires macOS Keychain
# (darwin only) — the workflow aborts gracefully on other platforms.
#
# Run with:
#   browserctl workflow run rakelib/smoke/session_encrypted.rb

SESSION_NAME = "smoke-enc-#{Process.pid}".freeze

Browserctl.workflow "smoke/session_encrypted" do
  desc "Smoke: encrypted session save, load, delete"

  step "guard — skip on non-darwin" do
    unless RUBY_PLATFORM.include?("darwin")
      puts "  [skip] session encryption requires macOS Keychain — skipping on #{RUBY_PLATFORM}"
      throw :abort
    end
  end

  step "setup — open page with state" do
    open_page(:sess, url: "https://example.com")
    puts "  [ok] page :sess opened"
  end

  step "session save --encrypt" do
    save_session(SESSION_NAME, encrypt: true)
    puts "  [ok] encrypted session saved as #{SESSION_NAME.inspect}"
  end

  step "verify .enc files on disk (no plaintext)" do
    sessions_dir = File.join(Browserctl::BROWSERCTL_DIR, "sessions", SESSION_NAME)
    assert Dir.exist?(sessions_dir), "session dir missing: #{sessions_dir}"
    assert File.exist?(File.join(sessions_dir, "cookies.json.enc")), "cookies.json.enc missing"
    assert !File.exist?(File.join(sessions_dir, "cookies.json")), "plaintext cookies.json should not exist"
    puts "  [ok] .enc files present, no plaintext"
  end

  step "close page before loading session" do
    close_page(:sess)
    pages = client.page_list[:pages]
    assert !pages.include?("sess"), "expected :sess closed"
    puts "  [ok] page :sess closed"
  end

  step "session load — restores page from encrypted session" do
    load_session(SESSION_NAME)
    pages = client.page_list[:pages]
    assert pages.include?("sess"), "expected :sess restored, got: #{pages.inspect}"
    puts "  [ok] encrypted session loaded — pages: #{pages.inspect}"
  end

  step "session delete" do
    client.session_delete(SESSION_NAME)
    sessions = list_sessions
    names = sessions.map { |s| s[:name] }
    assert !names.include?(SESSION_NAME), "expected #{SESSION_NAME.inspect} deleted"
    puts "  [ok] session deleted"
  end

  step "teardown" do
    client.page_close("sess")
  rescue StandardError
    nil
  end
end

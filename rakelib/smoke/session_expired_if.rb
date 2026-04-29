# frozen_string_literal: true

#
# Smoke test: load_session with expired_if: — stale session detection and auto-recovery.
#
# Exercises both paths of the expired_if: feature introduced in v0.8.3:
#
#   1. Live path   — session was saved with the auth marker present; expired_if
#                    returns false and the fallback is never invoked.
#   2. Expired path — session was saved WITHOUT the auth marker (simulating a
#                    stale/logged-out save); expired_if returns true, the fallback
#                    sets the marker and re-saves, and the second check passes.
#
# The "auth marker" is a localStorage key (auth_valid=1) that acts as a
# stand-in for a real server-side session cookie or token. example.com is
# required because Chrome denies localStorage access on about:blank.
#
# Run with:
#   browserctl workflow run rakelib/smoke/session_expired_if.rb

SESSION_LIVE    = "smoke-expired-if-live-#{Process.pid}".freeze
SESSION_STALE   = "smoke-expired-if-stale-#{Process.pid}".freeze
FALLBACK_WF     = "smoke/session_expired_if/fallback".freeze

# ---------------------------------------------------------------------------
# Fallback workflow — simulates re-authentication by setting the auth marker
# and re-saving the stale session. Invoked automatically by load_session when
# expired_if returns true.
# ---------------------------------------------------------------------------
Browserctl.workflow FALLBACK_WF do
  desc "Smoke: re-auth fallback for expired_if: test"

  step "re-authenticate (set marker + save)" do
    page(:sess).storage_set("auth_valid", "1")
    save_session(SESSION_STALE)
    puts "    [ok] fallback ran — auth marker set and session re-saved"
  end
end

# ---------------------------------------------------------------------------
# Main smoke workflow
# ---------------------------------------------------------------------------
Browserctl.workflow "smoke/session_expired_if" do
  desc "Smoke: load_session with expired_if: (live + expired recovery paths)"

  # -- Setup: two sessions, one live, one stale --------------------------------

  step "setup — save live session (auth_valid=1 present)" do
    open_page(:sess, url: "https://example.com")
    page(:sess).storage_set("auth_valid", "1")
    save_session(SESSION_LIVE)
    close_page(:sess)
    puts "  [ok] live session saved as #{SESSION_LIVE.inspect}"
  end

  step "setup — save stale session (auth_valid absent)" do
    open_page(:sess, url: "https://example.com")
    # deliberately do NOT set auth_valid — simulates a logged-out save
    save_session(SESSION_STALE)
    close_page(:sess)
    puts "  [ok] stale session saved as #{SESSION_STALE.inspect}"
  end

  # -- Path 1: live session — expired_if should return false -------------------

  step "live path — expired_if returns false, fallback not invoked" do
    load_session(SESSION_LIVE,
                 fallback: FALLBACK_WF,
                 expired_if: -> { page(:sess).storage_get("auth_valid") != "1" })
    val = page(:sess).storage_get("auth_valid")
    assert val == "1", "expected auth_valid=1, got #{val.inspect}"
    close_page(:sess)
    puts "  [ok] live session loaded — no fallback invoked"
  end

  # -- Path 2: stale session — expired_if should trigger fallback --------------

  step "expired path — expired_if returns true, fallback recovers session" do
    load_session(SESSION_STALE,
                 fallback: FALLBACK_WF,
                 expired_if: -> { page(:sess).storage_get("auth_valid") != "1" })
    val = page(:sess).storage_get("auth_valid")
    assert val == "1", "expected auth_valid=1 after recovery, got #{val.inspect}"
    close_page(:sess)
    puts "  [ok] stale session recovered — fallback invoked, auth marker now present"
  end

  # -- Cleanup -----------------------------------------------------------------

  step "teardown — delete smoke sessions" do
    client.session_delete(SESSION_LIVE)
    client.session_delete(SESSION_STALE)
    puts "  [ok] smoke sessions deleted"
  rescue StandardError
    nil
  end
end

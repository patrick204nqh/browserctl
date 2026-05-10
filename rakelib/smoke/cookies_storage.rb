# frozen_string_literal: true

#
# Smoke test: cookie operations + localStorage/sessionStorage operations.
#
# Navigates to https://example.com for a real HTTP origin (needed for
# localStorage and domain-scoped cookies). Requires internet access.
#
# Run with:
#   browserctl workflow run examples/smoke/cookies_storage.rb

require "json"

COOKIES_BASE_URL = "https://example.com"
SMOKE_DOMAIN     = "example.com"

Browserctl.workflow "smoke/cookies_storage" do
  desc "Smoke: cookie set/list/export/import/delete + storage set/get/export/import/delete"

  param :base_url, default: COOKIES_BASE_URL

  step "setup — open page at real HTTP origin" do
    open_page(:cs, url: base_url)
  end

  # ── Cookies ─────────────────────────────────────────────────────────────────

  step "cookie set" do
    res = client.set_cookie("cs", "smoke_cookie", "smoke_value", SMOKE_DOMAIN)
    assert !res[:error], "set_cookie failed: #{res[:error]}"
  end

  step "cookie list — contains the set cookie" do
    res = client.cookies("cs")
    assert res[:cookies].is_a?(Array), "expected cookies array"
    names = res[:cookies].map { |c| c[:name] }
    assert names.include?("smoke_cookie"), "expected smoke_cookie in #{names.inspect}"
  end

  step "cookie export and import" do
    export_path = "/tmp/browserctl_smoke_cookies_#{Process.pid}.json"

    client.export_cookies("cs", export_path)
    assert File.exist?(export_path), "export file not created"
    assert File.size(export_path).positive?, "export file is empty"

    # Clear first, then re-import
    page(:cs).delete_cookies
    before_import = client.cookies("cs")[:cookies]
    assert !before_import.map { |c| c[:name] }.include?("smoke_cookie"),
           "expected smoke_cookie cleared before import"

    client.import_cookies("cs", export_path)
    after_import = client.cookies("cs")[:cookies]
    names = after_import.map { |c| c[:name] }
    assert names.include?("smoke_cookie"), "expected smoke_cookie restored after import"

    File.unlink(export_path)
  end

  step "cookie delete — clears all cookies" do
    page(:cs).delete_cookies
    remaining = client.cookies("cs")[:cookies]
    smoke = remaining.find { |c| c[:name] == "smoke_cookie" }
    assert smoke.nil?, "expected smoke_cookie deleted, still present"
  end

  # ── Storage ──────────────────────────────────────────────────────────────────

  step "storage set and get — localStorage" do
    page(:cs).storage_set("smoke_key", "smoke_val")
    value = page(:cs).storage_get("smoke_key")
    assert value == "smoke_val", "expected 'smoke_val', got: #{value.inspect}"
  end

  step "storage set and get — sessionStorage" do
    page(:cs).storage_set("sess_key", "sess_val", store: "session")
    value = page(:cs).storage_get("sess_key", store: "session")
    assert value == "sess_val", "expected 'sess_val', got: #{value.inspect}"
  end

  step "storage get — nil for missing key" do
    value = page(:cs).storage_get("no_such_smoke_key_xyz")
    assert value.nil?, "expected nil for missing key, got: #{value.inspect}"
  end

  step "storage export and import" do
    export_path = "/tmp/browserctl_smoke_storage_#{Process.pid}.json"

    res = client.storage_export("cs", export_path)
    assert !res[:error], "storage_export failed: #{res[:error]}"
    assert File.exist?(export_path), "storage export file not created"

    # Clear then reimport
    client.storage_delete("cs")
    assert page(:cs).storage_get("smoke_key").nil?, "expected storage cleared before import"

    res2 = client.storage_import("cs", export_path)
    assert !res2[:error], "storage_import failed: #{res2[:error]}"
    restored = page(:cs).storage_get("smoke_key")
    assert restored == "smoke_val", "expected 'smoke_val' restored, got: #{restored.inspect}"

    File.unlink(export_path)
  end

  step "storage delete — clears localStorage" do
    client.storage_delete("cs", stores: "local")
    assert page(:cs).storage_get("smoke_key").nil?, "expected localStorage cleared"
  end

  step "storage delete — clears sessionStorage" do
    client.storage_delete("cs", stores: "session")
    assert page(:cs).storage_get("sess_key", store: "session").nil?,
           "expected sessionStorage cleared"
  end

  step "teardown" do
    page(:cs).delete_cookies
    client.storage_delete("cs")
    close_page(:cs)
  end
end

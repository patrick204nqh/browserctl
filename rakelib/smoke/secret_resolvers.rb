# frozen_string_literal: true

#
# Smoke test: secret resolver plugin system.
#
# Uses env:// (the only built-in resolver with no external tool dependency)
# to verify the full path: param declaration → registry dispatch → value
# available inside a step.
#
# Requires BCTL_SMOKE_SECRET to be set in the environment.
# The rake task sets it automatically.

Browserctl.workflow "smoke/secret_resolvers" do
  desc "Smoke: env:// secret resolver resolves param at runtime"

  param :secret_value, secret_ref: "env://BCTL_SMOKE_SECRET"

  step "assert secret was resolved" do
    assert secret_value == "smoke-secret-ok",
           "expected 'smoke-secret-ok', got: #{secret_value.inspect}"
    puts "  [ok] env:// resolver returned correct value"
  end

  step "assert missing env var raises SecretResolverError" do
    missing = "BCTL_SMOKE_MISSING_#{SecureRandom.hex(8)}"
    Browserctl::SecretResolverRegistry.resolve("env://#{missing}")
    assert false, "expected SecretResolverError was not raised"
  rescue Browserctl::SecretResolverError => e
    puts "  [ok] SecretResolverError raised as expected: #{e.message}"
  end
end

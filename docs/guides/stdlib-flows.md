# Standard Library Flows

browserctl ships a small set of reusable flows for the auth steps that
appear in almost every login workflow. They live in
`lib/browserctl/flows/stdlib/` and are auto-discovered after
`require "browserctl"` (or via the `flow run` CLI), so you can invoke
them by name without copying code into your project.

| Flow | Purpose |
|---|---|
| `totp_2fa` | Generate a TOTP code from a base32 secret and type it into the page |

More flows arrive in v0.10 (basic_auth, magic_link_email, oauth_google,
oauth_github, cloudflare_solve).

---

## `totp_2fa`

RFC 6238 TOTP code generator. No network — purely computes a six-digit
code from the secret and the current time.

### Params

| Name | Type | Default | Notes |
|---|---|---|---|
| `secret` | base32 string | — | **Required.** Marked `secret: true`. Pair with `secret_ref:` in the workflow. |
| `selector` | CSS | — | **Required.** The input the code is typed into. |
| `digits` | int | `6` | Match your provider's setting. |
| `period` | int | `30` | Seconds per code. |

### From a workflow

```ruby
Browserctl.workflow "github_login" do
  step "open login" do
    open_page(:main, url: "https://github.com/login")
    page(:main).fill("input#login_field", "patrick")
    page(:main).fill("input#password", ENV.fetch("GH_PASS"))
    page(:main).click("input[type='submit']")
  end

  step "submit 2fa" do
    invoke :totp_2fa,
           page: :main,
           secret: ENV.fetch("GH_TOTP_SECRET"),
           selector: "input#otp"
    page(:main).click("button[type='submit']")
  end
end
```

The `page:` kwarg tells `invoke` which workflow page proxy to hand to
the flow.

### From the CLI

```sh
browserctl flow run totp_2fa \
  --page main \
  --secret JBSWY3DPEHPK3PXP \
  --selector "input#otp"
```

The daemon must be running and the page named `main` must already be
open (use `browserctl page open main --url ...` first).

### Sourcing the secret from somewhere safer

Don't pass the secret on the command line — it lands in shell history
and `ps aux`. From a workflow, declare a `param ... secret_ref:` once
and let browserctl resolve it:

```ruby
param :totp_secret, secret_ref: "env://GH_TOTP_SECRET"
# or:
param :totp_secret, secret_ref: "op://Personal/GitHub/totp"
# or:
param :totp_secret, secret_ref: "keychain://github-totp"
```

Then forward it to the flow:

```ruby
invoke :totp_2fa,
       page: :main,
       secret: totp_secret,
       selector: "input#otp"
```

### Verifying it works

The flow ships with RFC 6238 vector tests; you can run them yourself:

```sh
bundle exec rspec spec/unit/flows/stdlib/totp_2fa_spec.rb
```

If your provider's codes don't match what the flow generates, the
secret is wrong (most common), or the provider uses non-default
`digits` or `period` (rare — check your provisioning URI).

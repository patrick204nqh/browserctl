# Standard Library Flows

browserctl ships a small set of reusable flows for the auth steps that
appear in almost every login workflow. They live in
`lib/browserctl/flows/stdlib/` and are auto-discovered after
`require "browserctl"` (or via the `flow run` CLI), so you can invoke
them by name without copying code into your project.

| Flow | Purpose |
|---|---|
| `totp_2fa` | Generate a TOTP code from a base32 secret and type it into the page |
| `basic_auth` | Navigate to an HTTP Basic Auth URL with credentials embedded |
| `magic_link_email` | Pause for a magic link, then navigate to it |

More flows arrive later in v0.10 (oauth_google, oauth_github,
cloudflare_solve).

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

---

## `basic_auth`

For sites protected by real HTTP Basic Auth (the browser pops a native
auth prompt). The flow side-steps the dialog by navigating to the URL
with credentials in the userinfo portion — Chromium ingests them and
sends the `Authorization: Basic ...` header on the request.

This is **not** for form-based logins (input fields named "username"
and "password" in the page). For those, use a workflow that calls
`page.fill` directly.

### Params

| Name | Type | Default | Notes |
|---|---|---|---|
| `url` | string | — | **Required.** Full URL of the protected resource. |
| `username` | string | — | **Required.** |
| `password` | string | — | **Required.** Marked `secret: true`. |

The flow URL-encodes both credentials, so `@`, `/`, `:`, and other
reserved chars in the password are handled correctly.

### From a workflow

```ruby
Browserctl.workflow "scrape_internal_dashboard" do
  step "load" do
    open_page(:main)
    invoke :basic_auth,
           page: :main,
           url: "https://internal.example.com/dashboard",
           username: "patrick",
           password: ENV.fetch("DASHBOARD_PASS")
  end
end
```

### From the CLI

```sh
browserctl flow run basic_auth \
  --page main \
  --url https://internal.example.com/ \
  --username patrick \
  --password "$DASHBOARD_PASS"
```

---

## `magic_link_email`

Many SaaS apps (Slack, Notion, Linear, ...) email a one-shot login link
instead of accepting a password. This flow handles the "click the link
in your email" step by pausing for the human to paste the link, then
navigating the page to it.

It does **not** read your inbox — that would require provider-specific
IMAP/Gmail integration which doesn't belong in stdlib. If you want
fully automated magic-link login, write a vendor flow that resolves the
link from your mail provider's API, then call `page.navigate(link)`
directly.

### Params

| Name | Type | Default | Notes |
|---|---|---|---|
| `prompt` | string | "Paste the magic link from your email:" | Override to give the user more context. |

### Behaviour

1. Prints the prompt to **stderr** (so it stays out of any JSON output
   pipeline you might be scripting around).
2. Reads one line from stdin.
3. Validates the line starts with `http://` or `https://`. Refuses
   `javascript:`, `file:`, etc.
4. Calls `page.navigate(link)`.

### From a workflow

```ruby
Browserctl.workflow "linear_login" do
  step "request link" do
    open_page(:main, url: "https://linear.app/login")
    page(:main).fill("input#email", "patrick@example.com")
    page(:main).click("button[type='submit']")
  end

  step "open the link" do
    invoke :magic_link_email,
           page: :main,
           prompt: "Paste the Linear sign-in link:"
  end
end
```

### From the CLI

```sh
browserctl flow run magic_link_email --page main
# [browserctl] Paste the magic link from your email: <paste>
```

The shell session must be interactive — the flow reads from stdin
synchronously.

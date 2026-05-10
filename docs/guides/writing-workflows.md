# Writing Workflows

Workflows are Ruby files that automate multi-step browser interactions using the `Browserctl.workflow` DSL. They run in-process through the same client as the CLI, so every `page(:name)` call talks to the live `browserd` daemon.

## File placement

Place workflow files in either:

| Location | Scope |
|---|---|
| `.browserctl/workflows/<name>.rb` | Project-level (committed to repo) |
| `~/.browserctl/workflows/<name>.rb` | User-level (shared across projects) |

The filename becomes the workflow name used with `workflow run`.

---

## Minimal structure

```ruby
Browserctl.workflow "hello" do
  desc "Open a page and print its URL"

  step "open page" do
    open_page(:main, url: "https://example.com")
  end

  step "print url" do
    puts page(:main).url
  end
end
```

```bash
browserctl workflow run hello
```

---

## DSL reference

### `desc`

```ruby
desc "Human-readable description shown by browserctl workflow list"
```

### `param`

Declares an input parameter. Available as a method inside every `step` block.

```ruby
param :email,    required: true
param :password, required: true,  secret: true
param :base_url, default: "https://app.example.com"
```

| Option | Default | Behaviour |
|---|---|---|
| `required: true` | false | Raises if not supplied at runtime |
| `secret: true` | false | Value is never written to session recordings |
| `default:` | nil | Used when the caller omits the param |

Pass params at runtime with `--key value` flags:

```bash
browserctl workflow run my_workflow --email me@example.com --password s3cr3t
```

Or load them from a YAML or JSON file to keep credentials out of your shell history:

```bash
browserctl workflow run my_workflow --params .browserctl/params.yml
```

```yaml
# .browserctl/params.yml  (git-ignored)
email: me@example.com
password: s3cr3t
```

CLI `--key value` flags take priority over file params when both are provided. Both `.yml`/`.yaml` and `.json` extensions are supported.

### `step`

Steps run in order. A step that raises halts the workflow and marks it `[fail]`.

```ruby
step "label shown in output" do
  # any Ruby — page proxies, assertions, plain logic
end
```

Both `retry_count:` and `timeout:` are optional and independent:

```ruby
# retry up to 3 times before failing
step "submit form", retry_count: 3 do
  page(:main).click("button[type=submit]")
end

# fail the step if it takes longer than 10 seconds
step "wait for results", timeout: 10 do
  page(:main).wait(".results-list")
end

# combine both
step "flaky network call", retry_count: 2, timeout: 30 do
  page(:main).evaluate("fetch('/api/data').then(r => r.json())")
end
```

| Option | Default | Behaviour |
|---|---|---|
| `retry_count: N` | 0 | Retry the step up to N additional times on any error |
| `timeout: seconds` | nil | Raise `WorkflowError` if the step exceeds this duration |

### `store` and `fetch`

Pass values between steps in the same workflow run — useful for OTP codes, extracted text, or anything computed in one step and consumed in a later one.

```ruby
step "read confirmation code" do
  code = page(:inbox).evaluate("document.querySelector('.otp-code')?.innerText?.trim()")
  store(:otp, code)
end

step "enter code on target site" do
  page(:app).fill("input#otp", fetch(:otp))
  page(:app).click("button[type=submit]")
end
```

`fetch` raises `WorkflowError` with a descriptive message if the key was never stored. Values are stored in the daemon's KV store and persist for as long as the daemon is running — a later `workflow run` that connects to the same daemon can read a value stored by an earlier run. Values are lost when the daemon stops.

> **Use plain Ruby for step-to-step data; use `store`/`fetch` for cross-run data.**
>
> Inside a workflow, `@variable = value` works in every step block and is local to this run:
>
> ```ruby
> step "capture OTP" do
>   @otp = page(:inbox).evaluate("document.querySelector('.otp').textContent")
> end
>
> step "submit OTP" do
>   page(:app).fill("input#otp", @otp)
> end
> ```
>
> `store`/`fetch` call the daemon's KV store — values **persist after the workflow finishes** and are readable by any later workflow run against the same daemon. Use them for cross-run sharing, not within a single run.

---

### `assert`

Raises `WorkflowError` with a message if the condition is falsy.

```ruby
assert page(:main).url.include?("/dashboard"), "expected redirect to dashboard"
assert count == 3, "expected 3 items, got #{count}"
```

### `open_page` and `close_page`

Open or close a named browser page from within a workflow step.

```ruby
step "open login page" do
  open_page(:login, url: "https://app.example.com/login")
end

step "open dashboard separately" do
  open_page(:dashboard)
  page(:dashboard).navigate("#{base_url}/dashboard")
end

step "close login tab when done" do
  close_page(:login)
end
```

`open_page` without a `url:` creates the page but does not navigate. Navigate separately with `page(:name).navigate(url)` or pass `url:` directly.

### `save_state` and `load_state`

Persist cookies + storage as a single `.bctl` state bundle, optionally bound to a flow that re-authenticates when the bundle is detected as expired. Load it back in a later run or on a fresh daemon.

```ruby
step "save authenticated state" do
  save_state("github_work", flow: :github_login)
end

step "restore state" do
  load_state("github_work")
end
```

State bundles live under `~/.browserctl/state/<name>.bctl`. Binding a flow at save time lets `load_state` auto-rotate when the daemon detects `AUTH_REQUIRED` while applying the bundle — the bound flow runs, a fresh bundle is saved, and the load is retried. No caller code change required.

For bespoke recovery procedures, pass `on_auth_required:` to override the auto path:

```ruby
step "restore or rotate" do
  load_state("myapp", on_auth_required: -> { invoke("login_myapp") })
end
```

See [docs/concepts/state.md](../concepts/state.md) for the full state lifecycle.

### Sourcing secrets with `secret_ref:`

Instead of passing credentials through CLI flags or environment variables, declare where a param's value should come from using `secret_ref:`:

```ruby
param :password,  secret_ref: "keychain://MyApp/admin"
param :api_token, secret_ref: "op://Personal/Gmail/api_token"
param :ci_key,    secret_ref: "env://CI_SECRET_TOKEN"
```

The value is resolved at workflow runtime — never stored in the workflow file, never passed on the command line. `secret_ref:` always implies `secret: true`, so the value is automatically masked from session recordings regardless of the `secret:` keyword.

**Built-in URI schemes:**

| Scheme | Source | Reference format |
|---|---|---|
| `env://` | Environment variable | `env://VAR_NAME` |
| `keychain://` | macOS Keychain (via `security` CLI) | `keychain://service/account` |
| `op://` | 1Password CLI (`op read`) | `op://vault/item/field` — native 1Password URI format |

`keychain://` requires macOS with the `security` command. `op://` requires the [1Password CLI](https://developer.1password.com/docs/cli/) (`op`) to be installed and signed in. Both resolvers raise `SecretResolverError` with a clear message if the item is not found or the tool is unavailable.

**How to store the secret (one-time setup):**

`env://` — export the variable in your shell before running the workflow:

```sh
export GMAIL_PASSWORD="hunter2"
browserctl workflow run my_workflow.rb
```

Or add it to your shell profile (`~/.zshrc`, `~/.bashrc`) or a project-local `.envrc` (loaded by [direnv](https://direnv.net)) so it's available without exporting each time:

```sh
# .envrc  (project root, git-ignored)
export GMAIL_PASSWORD="hunter2"
```

`keychain://` — store the password once with the macOS `security` CLI. The reference format is `keychain://service/account`, where **service** is any label you choose and **account** is the username or identifier:

```sh
# store (omit -w to be prompted — avoids the password landing in shell history)
security add-generic-password -s "MyApp" -a "admin"

# or pass it inline (convenient, but the value appears in ~/.zsh_history)
security add-generic-password -s "MyApp" -a "admin" -w "hunter2"

# verify it round-trips
security find-generic-password -s "MyApp" -a "admin" -w
```

Then in your workflow:

```ruby
param :password, secret_ref: "keychain://MyApp/admin"
```

At runtime browserctl calls `security find-generic-password` transparently — no prompt, no value in the workflow file.

`op://` — the reference is the native 1Password CLI format. Sign in once, then point `secret_ref:` at the item:

```sh
# sign in (one-time per session)
op signin

# verify the reference resolves
op read "op://Personal/Gmail/password"
```

```ruby
param :password, secret_ref: "op://Personal/Gmail/password"
```

**Adding a resolver for another secret manager:**

Create `~/.browserctl/resolvers.rb` (loaded automatically at daemon startup):

```ruby
# ~/.browserctl/resolvers.rb
class BitwardenResolver < Browserctl::SecretResolvers::Base
  def self.scheme = "bw"

  def resolve(reference)
    result, status = Open3.capture2("bw", "get", "password", reference)
    raise Browserctl::SecretResolverError, "Bitwarden item not found: #{reference}" unless status.success?
    result.chomp
  end
end

Browserctl::SecretResolverRegistry.register(BitwardenResolver)
```

Then use it like any built-in:

```ruby
param :vault_secret, secret_ref: "bw://My Item Name"
```

### `page(:name)`

Returns a `PageProxy` for a named browser page. The page must already be open (via `open_page` or `browserctl page open`) before calling methods on it.

```ruby
page(:login).fill("input[name=email]", email)
page(:login).click("button[type=submit]")
```

## Composing workflows (`compose`)

`compose` splices another workflow's steps into the current workflow **at definition time**. The inlined steps run in the calling workflow's param scope.

```ruby
Browserctl.workflow "login" do
  param :email, required: true
  param :password, required: true, secret: true

  step "open login page" do
    open_page(:main, url: "https://app.example.com/login")
  end

  step "submit credentials" do
    page(:main).fill("input[name=email]", email)
    page(:main).fill("input[name=password]", password)
    page(:main).click("button[type=submit]")
  end
end

Browserctl.workflow "checkout_with_login" do
  param :email, required: true
  param :password, required: true, secret: true

  compose "login"   # inlines login's two steps here

  step "navigate to checkout" do
    page(:main).navigate("https://app.example.com/checkout")
  end
end
```

| | `compose` | `invoke` |
|---|---|---|
| When it runs | At workflow definition time | At runtime, inside a step block |
| Where to call it | Top level of the `workflow` block | Inside a `step` block |
| Param scope | Shares calling workflow's params | Can pass/override params |
| Use for | Structural reuse (bake steps in) | Parameterised delegation |

> `compose` must be called at the workflow definition level — not inside a `step` block. Use `invoke` for runtime delegation.

### `invoke`

Calls another workflow by name, optionally overriding params.

```ruby
invoke "smoke_login", email: admin_email, password: admin_password
```

Circular invocation (`a → b → a`) raises immediately.

---

## PageProxy methods

For the full list of `PageProxy` methods (including `ref:` keyword support on `fill`, `click`, `hover`, `upload`, and `select`), see [Command Reference → PageProxy methods](../reference/commands.md#pageproxy-methods).

All methods raise `WorkflowError` on a daemon error, which fails the current step.

For HITL pause/resume inside a workflow, use `client` — the raw daemon client available in every step block:

```ruby
step "handle challenge" do
  res = client.navigate("main", target_url)
  if res[:challenge]
    client.pause("main", message: "Solve the challenge, then: browserctl resume main")
    loop do
      snap = client.snapshot("main", format: "html")
      break unless snap[:challenge]
      sleep 3
    end
  end
end
```

For the complete `client` API, see the [Command Reference](../reference/commands.md).

---

## Full example

```ruby
# .browserctl/workflows/smoke_login.rb
Browserctl.workflow "smoke_login" do
  desc "Log in, verify the dashboard, then capture a screenshot"

  param :email,    required: true
  param :password, required: true, secret: true
  param :base_url, default: "https://app.example.com"

  step "open login page" do
    open_page(:main, url: "#{base_url}/login")
  end

  step "submit credentials" do
    page(:main).fill("input[name=email]",    email)
    page(:main).fill("input[name=password]", password)
    page(:main).click("button[type=submit]")
  end

  step "verify dashboard" do
    page(:main).wait("[data-test=dashboard]", timeout: 10)
    assert page(:main).url.include?("/dashboard"), "redirect to dashboard failed"
  end

  step "capture screenshot" do
    page(:main).screenshot(path: "/tmp/smoke_login.png", full: true)
  end
end
```

```bash
browserctl workflow run smoke_login --email me@example.com --password s3cr3t
```

Expected output:

```
  [ok]   open login page
  [ok]   submit credentials
  [ok]   verify dashboard
  [ok]   capture screenshot
```

---

## Running a workflow by file path

If the file is not in a search path (e.g. a one-off script), pass the path directly:

```bash
browserctl workflow run path/to/my_workflow.rb --key value
```

---

## Listing and inspecting workflows

```bash
browserctl workflow list              # list all discoverable workflows with descriptions
browserctl workflow describe <name>   # show params and step labels for a workflow
```

---

## Patterns

### Keyboard and mouse

```ruby
step "navigate dropdown" do |ctx|
  p = page(:main)
  p.hover("#menu-trigger")    # mouse over to reveal the dropdown
  p.click("#menu-trigger")    # then click
  p.press("Escape")           # dismiss with keyboard
end
```

### File upload

```ruby
step "upload CV" do
  page(:main).upload("#resume-input", "/home/patrick/cv.pdf")
end
```

### Select

```ruby
step "choose country" do
  page(:main).select("#country", "AU")
end
```

### Dialog handling

Pre-register the handler **before** the action that triggers the dialog:

```ruby
step "delete record" do
  p = page(:main)
  p.dialog_accept        # register: accept the next confirm()
  p.click("#delete-btn") # triggers the confirm — auto-accepted
end
```

### Asking the human for a value

```ruby
step "enter 2FA" do
  code = ask("Enter the 2FA code sent to your phone:")
  page(:main).fill("#otp-input", code)
  page(:main).click("#verify")
end
```

### Waiting for async content

```ruby
step "wait for results" do
  page(:main).click("button#search")
  page(:main).wait(".results-list", timeout: 15)
  count = page(:main).evaluate("document.querySelectorAll('.result-item').length")
  assert count > 0, "no results returned"
end
```

### Saving and restoring state

Authenticate once, save the resulting cookies + storage as a `.bctl` state bundle, then load it in future runs to skip login entirely.

```bash
# After a successful login:
browserctl state save myapp --flow login_myapp

# On the next run (daemon restarted):
browserctl state load myapp
```

You can also do this inside a workflow:

```ruby
step "save state after login" do
  save_state("myapp", flow: :login_myapp)
end

step "restore authenticated state" do
  load_state("myapp")
  # bundle bound to login_myapp → daemon auto-rotates when AUTH_REQUIRED is hit
end
```

State bundles live under `~/.browserctl/state/`. The directory is git-ignored by default when you run `browserctl init`.

---

### Composing workflows with `invoke`

```ruby
Browserctl.workflow "full_checkout" do
  param :email,    required: true
  param :password, required: true, secret: true

  step "log in" do
    invoke "smoke_login", email: email, password: password
  end

  step "add to cart" do
    page(:main).click("[data-test=add-to-cart]")
  end

  step "complete checkout" do
    invoke "checkout_flow"
  end
end
```

### Human-in-the-loop inside a workflow

When a step hits a wall that needs human action, pause the session and resume when the human is done. See the full runnable example in [Human-in-the-Loop — The polling loop](../concepts/hitl.md#the-polling-loop).

See [Handling Challenges](handling-challenges.md) for a full runnable example.

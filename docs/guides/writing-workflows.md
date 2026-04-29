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

### `save_session` and `load_session`

Persist the full browser state — open pages, cookies, and localStorage — to a named session. Load it back in a later run or on a fresh daemon.

```ruby
step "save authenticated session" do
  save_session("github_work")
end

step "restore session" do
  load_session("github_work")
end
```

Sessions are stored as plain JSON files in `~/.browserctl/sessions/<name>/`. Use `list_sessions` to see all saved sessions.

#### Recovering from an expired session

Pass `fallback:` to automatically invoke a named login workflow when the session is missing or fails to load, then retry:

```ruby
step "restore or login" do
  load_session("gmail_prod", fallback: "login_gmail")
end
```

If `session_load` fails, browserctl calls `invoke("login_gmail")` and retries the load once. The fallback workflow is responsible for saving the refreshed session via `save_session`. If the session is still unavailable after the fallback runs, a `WorkflowError` is raised with a descriptive message.

This replaces the common hand-rolled pattern:

```ruby
# before — every workflow had to do this manually
step "restore or login" do
  if list_sessions.none? { |s| s[:name] == "gmail_prod" }
    invoke("login_gmail")
  else
    load_session("gmail_prod")
  end
end
```

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

### `invoke`

Calls another workflow by name, optionally overriding params.

```ruby
invoke "smoke_login", email: admin_email, password: admin_password
```

Circular invocation (`a → b → a`) raises immediately.

---

## PageProxy methods

| Method | Description |
|---|---|
| `navigate(url)` | Navigate the page to a URL |
| `fill(selector, value)` | Fill an input field |
| `click(selector)` | Click an element |
| `wait(selector, timeout: 30)` | Wait until selector appears (default 30s) |
| `url` | Return the current page URL as a string |
| `evaluate(expression)` | Evaluate a JS expression and return the result |
| `snapshot(**opts)` | Return a DOM snapshot |
| `screenshot(**opts)` | Take a screenshot |
| `storage_get(key, store: "local")` | Read a localStorage or sessionStorage key |
| `storage_set(key, value, store: "local")` | Write a localStorage or sessionStorage key |
| `delete_cookies` | Delete all cookies for this page |
| `devtools` | Return the Chrome DevTools URL for this page |
| `press(key)` | Fire a `keydown` + `keyup` event for the given key |
| `hover(selector)` | Move the mouse to the centre of the matched element |
| `upload(selector, path)` | Set a file input's value to a file path |
| `select(selector, value)` | Set a `<select>` element's value and fire a `change` event |

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

### Saving and restoring a session

Authenticate once, save the full session, then load it in future runs to skip login entirely.

```bash
# After a successful login session:
browserctl session save myapp

# On the next run (daemon restarted):
browserctl session load myapp
```

You can also do this inside a workflow:

```ruby
step "restore authenticated session" do
  load_session("myapp")
end

step "save session after login" do
  save_session("myapp")
end
```

To recover automatically when the session is missing or expired, pass `fallback:` with the name of a login workflow:

```ruby
step "restore or login" do
  load_session("myapp", fallback: "login_myapp")
  # if the session doesn't exist or fails to load:
  # → invokes "login_myapp", then retries the load once
end
```

Sessions capture cookies, localStorage, and all open page URLs. The `~/.browserctl/sessions/` directory is git-ignored by default when you run `browserctl init`.

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

When a step hits a wall that needs human action, pause the session and resume when the human is done:

```ruby
step "navigate to protected page" do
  res = client.navigate("main", target_url)
  if res[:challenge]
    puts "→ Challenge detected. Solve it in the browser, then: browserctl resume main"
    client.pause("main")
    loop do
      snap = client.snapshot("main", format: "html")
      break unless snap[:challenge]
      sleep 3
    end
  end
end
```

See [Handling Challenges](handling-challenges.md) for a full runnable example.

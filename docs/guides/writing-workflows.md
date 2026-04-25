# Writing Workflows

Workflows are Ruby files that automate multi-step browser interactions using the `Browserctl.workflow` DSL. They run in-process through the same client as the CLI, so every `page(:name)` call talks to the live `browserd` daemon.

## File placement

Place workflow files in either:

| Location | Scope |
|---|---|
| `.browserctl/workflows/<name>.rb` | Project-level (committed to repo) |
| `~/.browserctl/workflows/<name>.rb` | User-level (shared across projects) |

The filename becomes the workflow name used with `browserctl run`.

---

## Minimal structure

```ruby
Browserctl.workflow "hello" do
  desc "Open a page and print its URL"

  step "open page" do
    page(:main).goto("https://example.com")
  end

  step "print url" do
    puts page(:main).url
  end
end
```

```bash
browserctl run hello
```

---

## DSL reference

### `desc`

```ruby
desc "Human-readable description shown by browserctl workflows"
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
browserctl run my_workflow --email me@example.com --password s3cr3t
```

Or load them from a YAML or JSON file to keep credentials out of your shell history:

```bash
browserctl run my_workflow --params .browserctl/params.yml
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
  page(:main).wait_for(".results-list")
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

`fetch` raises `KeyError` with a descriptive message if the key was never stored. Stored values do not persist across separate `browserctl run` invocations.

---

### `assert`

Raises `WorkflowError` with a message if the condition is falsy.

```ruby
assert page(:main).url.include?("/dashboard"), "expected redirect to dashboard"
assert count == 3, "expected 3 items, got #{count}"
```

### `page(:name)`

Returns a `PageProxy` for a named browser page. The page must have been opened (via `browserctl open` or `page(:name).goto`) before calling other methods on it.

```ruby
page(:login).goto("https://app.example.com/login")
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
| `goto(url)` | Navigate the page to a URL |
| `fill(selector, value)` | Fill an input field |
| `click(selector)` | Click an element |
| `wait_for(selector, timeout: 10)` | Wait up to N seconds for an element to appear |
| `url` | Return the current page URL as a string |
| `evaluate(expression)` | Evaluate a JS expression and return the result |
| `snapshot(**opts)` | Return a DOM snapshot (same as `browserctl snap`) |
| `screenshot(**opts)` | Take a screenshot (same as `browserctl shot`) |

All methods raise `WorkflowError` on a daemon error, which fails the current step.

For HITL pause/resume and direct cookie management inside a workflow, use `client` — the raw daemon client available in every step block:

```ruby
step "handle challenge" do
  res = client.goto("main", url)
  if res[:challenge]
    client.pause("main")
    loop { break unless client.snapshot("main", format: "html")[:challenge]; sleep 3 }
  end
end

step "restore session" do
  client.import_cookies("main", ".browserctl/sessions/app.json")
end
```

For the complete `client` API, see the [Command Reference](../reference/commands.md).

---

## Full example

```ruby
# .browserctl/workflows/smoke_login.rb
Browserctl.workflow "smoke_login" do
  desc "Log in, verify the dashboard, then log out"

  param :email,    required: true
  param :password, required: true, secret: true
  param :base_url, default: "https://app.example.com"

  step "open login page" do
    page(:main).goto("#{base_url}/login")
  end

  step "submit credentials" do
    page(:main).fill("input[name=email]",    email)
    page(:main).fill("input[name=password]", password)
    page(:main).click("button[type=submit]")
  end

  step "verify dashboard" do
    page(:main).wait_for("[data-test=dashboard]", timeout: 10)
    assert page(:main).url.include?("/dashboard"), "redirect to dashboard failed"
  end

  step "capture screenshot" do
    page(:main).screenshot(path: "/tmp/smoke_login.png", full: true)
  end
end
```

```bash
browserctl run smoke_login --email me@example.com --password s3cr3t
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
browserctl run path/to/my_workflow.rb --key value
```

---

## Listing and inspecting workflows

```bash
browserctl workflows          # list all discoverable workflows with descriptions
browserctl describe <name>    # show params and step labels for a workflow
```

---

## Patterns

### Dropdown via JavaScript

browserctl has no native `select` command. Use `evaluate` to set the value directly:

```ruby
step "select option" do
  page(:main).evaluate("document.querySelector('select#plan').value = 'pro'")
end
```

### Waiting for async content

```ruby
step "wait for results" do
  page(:main).click("button#search")
  page(:main).wait_for(".results-list", timeout: 15)
  count = page(:main).evaluate("document.querySelectorAll('.result-item').length")
  assert count > 0, "no results returned"
end
```

### Skipping login with cookie export/import

Authenticate once, export the session, then import it in future runs to skip the login step entirely.

```bash
# After a successful login session:
browserctl export-cookies main .browserctl/sessions/app.json

# On the next run (daemon restarted):
browserctl import-cookies main .browserctl/sessions/app.json
```

The `sessions/` directory is git-ignored by default when you run `browserctl init`.

You can also do this inside a workflow:

```ruby
step "restore session" do
  client.import_cookies("main", ".browserctl/sessions/app.json")
end
```

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
  res = client.goto("main", target_url)
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

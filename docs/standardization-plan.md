# Standardization Plan

This document captures the architectural gaps, refactoring priorities, and implementation roadmap for making browserctl maintainable at v1.0 scale and beyond.

---

## Requirements

### User Stories

| ID | As a… | I want… | So that… |
|----|-------|---------|---------|
| R1 | plugin author | a stable, documented extension API | I can add commands and detectors without reading private source |
| R2 | workflow author | meaningful error messages from every daemon command | I can debug failures without adding `puts` everywhere |
| R3 | contributor | each file to have a single, named responsibility | I can find and change things without reading all 320 lines of CommandDispatcher |
| R4 | security reviewer | all HITL detectors in a separate, auditable module | I can verify detection logic independently of dispatch logic |
| R5 | agent consumer | typed RBS signatures on the public API | I can use Steep/Sorbet to catch integration errors at tooling time |
| R6 | ops user | a Homebrew formula | I can install `browserctl` on a clean machine with one command |

### Acceptance Criteria

**R1 — Plugin API stability**
- `Browserctl.register_command` and `Browserctl.register_detector` are the only public extension points
- Both have RBS signatures
- A breaking change to either increments the major version

**R2 — Error hierarchy**
- All daemon-side errors are subclasses of `Browserctl::Error`
- All errors have a `code:` symbol (`:page_not_found`, `:ref_not_found`, `:selector_not_found`)
- Agent-facing JSON responses include `code` alongside `error`

**R3 — File responsibility**
- No file exceeds 200 lines
- Each file corresponds to one named concept in the public documentation

**R4 — Detector isolation**
- `CLOUDFLARE_SIGNALS` and `cloudflare_challenge?` live in `lib/browserctl/detectors/cloudflare.rb`
- `CommandDispatcher` calls `Browserctl::Detectors.challenge?(page)` — no direct signal list access
- New detectors (DataDome, 2FA, consent) are individual files under `detectors/`

**R5 — RBS signatures**
- All public classes and methods have RBS coverage
- `steep check` passes in CI

**R6 — Homebrew**
- Formula published to `homebrew-tap`
- `brew install patrick204nqh/tap/browserctl` installs a working gem + Chrome dep check

---

## Design

### New directory layout

```
lib/browserctl/
  browserctl.rb            # module bootstrap, extension points
  constants.rb             # path helpers, IDLE_TTL
  version.rb
  error.rb                 # NEW: Browserctl::Error hierarchy
  client.rb
  runner.rb
  workflow.rb
  recording.rb
  logger.rb
  detectors/               # NEW: one file per HITL signal family
    base.rb                #   Detectors.challenge?(page) → bool
    cloudflare.rb          #   CLOUDFLARE_SIGNALS + detector logic
    registry.rb            #   register_detector / all_detectors
  server/
    command_dispatcher.rb  # routes to handlers; no detection logic
    handlers/              # NEW: one file per command group
      page_lifecycle.rb    #   open, close, list, goto, url
      interaction.rb       #   fill, click, evaluate
      snapshot.rb          #   snapshot, diff, watch, wait_for
      screenshot.rb        #   screenshot + safe_path logic
      cookies.rb           #   cookies, set_cookie, clear_cookies, import
      hitl.rb              #   pause, resume, inspect
      control.rb           #   ping, shutdown
    page_session.rb
    snapshot_builder.rb
    idle_watcher.rb
  commands/                # CLI → socket bridge (unchanged)
    ...
```

### Error hierarchy

```ruby
module Browserctl
  class Error < StandardError
    attr_reader :code
    def initialize(msg, code: :unknown) = (@code = code; super(msg))
  end

  class PageNotFoundError     < Error; end  # code: :page_not_found
  class RefNotFoundError      < Error; end  # code: :ref_not_found
  class SelectorNotFoundError < Error; end  # code: :selector_not_found
  class WorkflowError         < Error; end  # code: :workflow_error (existing)
  class PluginError           < Error; end  # code: :plugin_error
end
```

JSON response shape (extended, backward-compatible):
```json
{ "error": "no page named 'main'", "code": "page_not_found" }
```

### Detector module API

```ruby
# registration (in workflow files or plugins):
Browserctl.register_detector(:datadome) do |page|
  page.body.include?("datadome.co/js")
end

# internal use (CommandDispatcher):
Browserctl::Detectors.challenge?(page)   # → true/false
Browserctl::Detectors.fired_signals(page) # → [:cloudflare, :datadome] (for logging)
```

### Plugin registry (thread-safe)

Replace mutable constants with a mutex-protected registry:

```ruby
module Browserctl
  @_plugin_mutex    = Mutex.new
  @_plugin_commands = {}

  def self.register_command(name, &block)
    @_plugin_mutex.synchronize { @_plugin_commands[name.to_s] = block }
  end

  def self.plugin_command(name)
    @_plugin_mutex.synchronize { @_plugin_commands[name.to_s] }
  end
end
```

---

## Implementation Plan

### Phase 1 — v0.4 completion (current)

Close the two open v0.4 items from VISION.md.

| Task | Files | Priority |
|------|-------|----------|
| RBS signatures for all public API | `sig/` directory | High |
| YARD documentation | all public methods | Medium |

### Phase 2 — Structural refactor (target: v0.5)

No behaviour changes. Pure extraction and reorganisation.

| Task | Files changed | Acceptance |
|------|--------------|------------|
| 2.1 Add `Browserctl::Error` hierarchy | `lib/browserctl/error.rb` | All `{ error: "..." }` responses also include `code:` |
| 2.2 Extract `detectors/` module | `detectors/base.rb`, `detectors/cloudflare.rb`, `detectors/registry.rb` | `CommandDispatcher` has zero direct signal references |
| 2.3 Replace mutable PLUGIN_COMMANDS constant | `lib/browserctl.rb` | `@_plugin_commands` hash behind mutex |
| 2.4 Extract command handlers | `server/handlers/*.rb` | Each handler file < 80 lines |
| 2.5 Update `CommandDispatcher` | `server/command_dispatcher.rb` | Dispatcher is routing-only, < 60 lines |
| 2.6 Add `steep check` to CI | `.github/workflows/ci.yml` | CI fails on type errors |

Each task above is one PR. Order: 2.1 → 2.2 → 2.3 → (2.4 + 2.5 together) → 2.6.

Target milestone: **v0.5**.

### Phase 3 — Evidence + reproduction (target: v0.6)

New product capabilities, each as a discrete PR.

| Task | Description | VISION.md milestone |
|------|-------------|-------------------|
| 3.1 Evidence hooks | Auto-screenshot on HITL pause; configurable `on_error:` screenshot | v0.6 |
| 3.2 Session trace export | Structured JSON log of every command in a session; `browserctl export main` | v0.6 |
| 3.3 Detector registry expansion | DataDome, 2FA prompts, consent banners as built-in detectors | v0.6 |
| 3.4 `replay` command | Replay a recorded workflow step-by-step with live screenshots at each step | v0.6 |
| 3.5 Visual regression | `shot --compare baseline.png` with pixel diff | v0.7 |

### Phase 4 — Security audit (target: v0.5)

| Task | Notes |
|------|-------|
| Socket permissions | Verify `~/.browserctl/*.sock` is `0600`; add test |
| Workflow param sanitisation | Fuzz test `param` injection via CLI flags |
| Screenshot path traversal | Review `safe_screenshot_path`; add boundary tests |
| Plugin sandbox | Document what plugin code can/cannot access; consider `$SAFE` or explicit allowlist |

---

## What to Defer

These are valid ideas that should not enter scope before v0.7:

- Distributed sessions (fan-out across N named pages) — adds coordination complexity
- WebSocket transport alternative — Unix socket is the right default; add only when an explicit use case demands it
- GUI companion app — valid v0.7+ goal; not a blocker for earlier milestones
- Fine-tuning data export from HITL sessions — depends on evidence hooks (3.1/3.2) being stable first

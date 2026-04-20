# ADR-0005: Ruby DSL for Workflow Authoring

**Date**: 2026-04-20
**Status**: accepted
**Deciders**: Patrick

## Context

Users need a way to compose multi-step browser automation sequences that can be parameterized, shared, and reused. The authoring format must be expressive enough for conditional logic, loops, and assertions, while remaining readable to non-experts.

## Decision

Workflows are authored as Ruby files using a `Browserctl.workflow` DSL. Steps are defined as blocks with a description string. Parameters are declared with `param`, accessed as plain method calls inside blocks, and pages are accessed via `page(:name)` which returns a `PageProxy` wrapping the client.

## Alternatives Considered

### YAML-based workflow definition
- **Pros**: Familiar to CI/CD users; no Ruby knowledge required; safe (no arbitrary code execution)
- **Cons**: Cannot express conditionals, loops, or error handling without a custom DSL on top; every dynamic need becomes a special YAML key
- **Why not**: The expressiveness ceiling of YAML is hit quickly for real automation tasks. A custom YAML interpreter would reinvent a worse version of Ruby.

### Shell scripts calling the CLI
- **Pros**: Zero learning curve; composable with standard Unix tools
- **Cons**: Awkward string passing for complex params; no shared state between commands beyond what's in the browser; verbose for multi-step flows
- **Why not**: Shell is the right tool for one-liners but becomes unreadable for multi-step workflows with assertions and parameterization

### Lua embedded scripting
- **Pros**: Small runtime, designed for embedding
- **Cons**: Requires embedding a Lua runtime; separate language for Ruby developers; smaller ecosystem
- **Why not**: Adds runtime complexity with no benefit over using Ruby itself, since the daemon is already Ruby

## Consequences

### Positive
- Full Ruby available for conditionals, loops, error handling, and helper methods
- Readable block syntax: `step "description" do ... end` is self-documenting
- Shared workflow libraries are just Ruby files — standard `require` works
- Circular invocation detection prevents infinite loops via stack tracking

### Negative
- Workflows execute arbitrary Ruby — not sandboxed. Trust is assumed for workflow authors.
- Ruby knowledge required to write workflows (though not to run them)

### Risks
- `method_missing` on `WorkflowContext` for params creates a magic API — a mistyped param name silently returns nil rather than raising

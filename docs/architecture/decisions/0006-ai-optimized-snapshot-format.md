# ADR-0006: AI-Optimized DOM Snapshot Format

**Date**: 2026-04-20
**Status**: accepted
**Deciders**: Patrick

## Context

A primary use case is AI agents that need to understand what a page contains and interact with it. Sending full HTML to an LLM is token-expensive, noisy (scripts, styles, invisible elements), and hard to act on. A compact, structured representation is needed that an agent can reason about efficiently.

## Decision

The `snapshot` command returns a JSON array of interactable elements only. Each element has a stable `ref` (e1, e2, ...), `tag`, truncated `text` (80 chars max), a full CSS `selector`, and relevant `attributes` (type, name, placeholder, href, aria-label, role). Non-interactable elements are excluded entirely.

Interactable element filter: `<a>`, `<button>`, `<input>`, `<select>`, `<textarea>`, `[role=button]`, `[role=link]`, `[role=menuitem]`.

## Alternatives Considered

### Full HTML dump
- **Pros**: Complete information; no risk of missing elements
- **Cons**: Extremely token-expensive; includes scripts, styles, comments, invisible elements; hard for LLMs to locate actionable elements in noise
- **Why not**: Defeats the purpose of an AI-optimized format

### Accessibility tree (AXTree)
- **Pros**: Semantically clean; browser-native; what screen readers use
- **Cons**: CDP accessibility tree is inconsistent across pages; requires additional CDP roundtrips; less predictable structure
- **Why not**: The custom filter over Nokogiri gives more control and predictability over what is included

### Screenshot only
- **Pros**: Visual; captures layout context
- **Cons**: Cannot be parsed for selectors; token-expensive for vision models; no structured data for action targeting
- **Why not**: Screenshots complement snapshots but cannot replace structured element data for action commands

## Consequences

### Positive
- Dramatically reduced token usage vs. full HTML — typical page: ~200 elements vs. thousands of HTML nodes
- Stable `ref` values (e1, e2...) give agents a compact way to reference elements without repeating full selectors
- JSON is natively parseable by any LLM tool-use framework

### Negative
- Custom-rendered or shadow DOM components may not surface interactable elements correctly
- The 80-char text truncation can lose context for long button labels or link text

### Risks
- Filter list is opinionated — pages using unusual ARIA roles or custom elements may appear empty; can be extended as needed

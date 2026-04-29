# browserctl docs

> Navigate the web. Stay in session.

---

## Start here

**New to browserctl?** Read these in order:

1. [Getting Started](getting-started.md) — install, first session, first snapshot (5 min)
2. [Sessions and Pages](concepts/sessions-and-pages.md) — the daemon, named pages, session state
3. [Snapshots and Refs](concepts/snapshots-and-refs.md) — how the AI-friendly snapshot format works
4. [Human-in-the-Loop](concepts/hitl.md) — handling the parts of the web that fight back

---

## Concepts

Mental models before mechanics.

| | |
|---|---|
| [Sessions and Pages](concepts/sessions-and-pages.md) | Why a daemon beats a script, and what named pages give you |
| [Snapshots and Refs](concepts/snapshots-and-refs.md) | The compact JSON snapshot format and ref-based interaction |
| [Human-in-the-Loop](concepts/hitl.md) | Pause/resume, challenge detection, the extensible blocker model |
| [Secrets and Credentials](guides/writing-workflows.md#sourcing-secrets-with-secret_ref) | Secret resolver system — env://, keychain://, op://, and custom resolvers |

---

## Guides

Narrative how-tos for real tasks.

| | |
|---|---|
| [Writing Workflows](guides/writing-workflows.md) | Automate multi-step flows with the Ruby DSL |
| [Handling Challenges](guides/handling-challenges.md) | Cloudflare, 2FA, and the pause/resume pattern in practice |
| [Smoke Testing](guides/smoke-testing.md) | Ready-to-run examples against the-internet.herokuapp.com |

---

## Reference

Look things up without reading linearly.

| | |
|---|---|
| [Commands](reference/commands.md) | Every CLI command, flag, snapshot format, and PageProxy method |
| [API Stability](reference/api-stability.md) | Fixed / Stable / Extension zones, wire protocol contract |
| [Style Guide](reference/style-guide.md) | Naming conventions per layer — wire, CLI, SDK |

---

## Architecture

| | |
|---|---|
| [Diagrams & ADRs](architecture/README.md) | C4 diagrams and architecture decision records |

---

## Project

| | |
|---|---|
| [Product](product.md) | What browserctl is, who it's for, and what makes it different |
| [Vision & Roadmap](vision.md) | Philosophy, principles, and where the project is going |
| [vs. agent-browser](vs-agent-browser.md) | Technical comparison with Vercel's agent-browser |

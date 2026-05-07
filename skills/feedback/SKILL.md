---
name: feedback
description: Capture a browserctl product feedback entry as a local markdown file. Use when the user reports a bug, friction, missing feature, or doc gap in browserctl — phrases like "this is broken", "this should work differently", "the docs don't mention", "I wish browserctl could", or an explicit "/feedback".
user-invocable: true
---

# browserctl feedback capture

Save the user's feedback about browserctl as a structured markdown file in `.claude/feedback/` so it can be filed as a GitHub issue later without re-asking the user to repeat themselves.

## When to invoke

Trigger on any of:

- The user explicitly runs `/feedback` (with or without arguments).
- The user describes something that didn't work as expected with `browserctl`, `browserd`, or a workflow file — even mid-task.
- The user proposes a change to behaviour, defaults, flags, or docs.
- The user says something like "we should file this", "worth a bug report", "the docs are wrong".

If the user is mid-task and you spot a feedback-worthy moment, capture it without derailing the task: write the file, mention the path, then continue.

## Input

The user-supplied content (if any) appears as `$ARGUMENTS`. If empty, ask one focused question:

> "What's the feedback? Describe the issue, friction, or idea — include what you were doing when you noticed it."

## Determine type

Tag every entry with one or more types:

| Type | When to use |
|------|-------------|
| `bug` | Something behaved incorrectly or errored unexpectedly |
| `ux` | Something worked but felt awkward, slow, or confusing |
| `feature` | Something is missing that would make the tool more useful |
| `docs` | Documentation was wrong, missing, or misleading |

A single entry may cover more than one type — list all that apply.

## Gather context

Pull as much as possible from the current conversation without asking the user to repeat themselves:

- The exact command(s) that were run.
- What the user expected vs. what happened.
- Any workaround that surfaced.
- Relevant environment details (OS, browser, browserctl version if known).

If critical information is missing and can't be inferred, ask one focused question — not a list.

## Write the file

- Path: `.claude/feedback/YYYY-MM-DD-<slug>.md`
- `<slug>`: 3–5 word kebab-case summary (e.g. `click-js-button-no-fire`).
- Use today's actual date.

File template:

```markdown
# <short title>

**Date:** YYYY-MM-DD
**Type:** bug | ux | feature | docs (list all that apply)
**Area:** <the command or concept this relates to, e.g. `click`, `snapshot`, `workflow DSL`, `daemon`, `driver`>

## Summary

One or two sentences clear enough to file as a GitHub issue title + body.

## Context

What the user was doing when this came up. Include the exact command(s) if relevant.

## Expected behaviour

What should have happened.

## Actual behaviour

What happened instead. Include error output or screenshot paths if captured.

## Workaround

How to work around it today (if one exists).

## Suggested fix or improvement

Concrete suggestion — a wording change, new flag, changed default, new command, etc. Leave blank if unknown.

## Notes

Anything else useful for the maintainer.
```

Omit sections that don't apply (e.g. "Actual behaviour" for a pure feature request).

## After writing

Tell the user:

- The file path.
- The type(s) and area tagged.
- A one-line summary of what was captured.
- "When you're ready to file a GitHub issue, the content maps directly — title from Summary, body from the rest."

Do not open a browser, create a GitHub issue, or take any external action unless the user explicitly asks.

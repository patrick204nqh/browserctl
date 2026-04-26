Capture a product feedback entry for browserctl and save it as a local markdown file.

## What to do

The user has provided: $ARGUMENTS

If $ARGUMENTS is empty, ask:
> "What's the feedback? Describe the issue, friction, or idea — include what you were doing when you noticed it."

Then determine the feedback type from context:

| Type | When to use |
|------|-------------|
| `bug` | Something behaved incorrectly or errored unexpectedly |
| `ux` | Something worked but felt awkward, slow, or confusing |
| `feature` | Something is missing that would make the tool more useful |
| `docs` | Documentation was wrong, missing, or misleading |

A single entry may cover more than one type — list all that apply.

## Gather context

Pull as much as possible from the current conversation without asking the user to repeat themselves:
- What command was run (exact invocation)
- What the user expected vs. what happened
- Any workaround that was found
- Relevant environment details (OS, browserctl version if known)

If critical information is missing and can't be inferred, ask one focused question — not a list.

## Write the file

Filename: `.claude/feedback/YYYY-MM-DD-<slug>.md`  
Where `<slug>` is a 3–5 word kebab-case summary of the issue (e.g. `click-js-button-no-fire`).  
Use today's actual date.

File format:

```markdown
# <short title>

**Date:** YYYY-MM-DD  
**Type:** bug | ux | feature | docs (list all that apply)  
**Area:** <the command or concept this relates to, e.g. `click`, `snap`, `workflow DSL`, `daemon`>

## Summary

One or two sentences describing the issue or idea clearly enough to file as a GitHub issue title + body.

## Context

What the user was doing when this came up. Include the exact command(s) if relevant.

## Expected behaviour

What should have happened.

## Actual behaviour

What happened instead. Include error output or screenshots if captured.

## Workaround

How to work around it today (if one exists).

## Suggested fix or improvement

Concrete suggestion — a wording change, new flag, changed default, new command, etc.
Leave blank if unknown.

## Notes

Anything else useful for the maintainer.
```

Omit sections that don't apply (e.g. "Actual behaviour" for a feature request).

## After writing

Tell the user:
- The file path
- The type(s) and area tagged
- One-line summary of what was captured
- "When you're ready to file a GitHub issue, the content maps directly — title from Summary, body from the rest."

Do not open a browser, create a GitHub issue, or take any external action unless the user explicitly asks.

# ADR-0019: Format Versioning Convention

**Date**: 2026-05-10
**Status**: accepted
**Pairs with**: ADR-0014 (`.bctl` bundle format), ADR-0009 (error handling strategy — `PROTOCOL_MISMATCH` is the typed failure mode this ADR depends on).
**Deciders**: Patrick

## Context

By v0.11, browserctl writes four kinds of persisted artifact: state bundles
(`.bctl`), recording logs (JSONL), workflow files (Ruby), and drift reports.
Each is read back by a later browserctl invocation — sometimes by an older
build than the one that wrote it, sometimes by a newer one. The shapes of
these artifacts are still moving as the gem heads toward 1.0.

Until v0.12 there was no convention for declaring the format an artifact was
written in. Readers parsed best-effort. A field rename or a layout change
silently fell into one of two failure modes: a parse exception with no clue
about the cause, or — worse — a successful parse that produced wrong data.

The 1.0 contract has to do better than that. We need to be able to evolve
formats without breaking historical artifacts in the field, and we need
failure to be explicit when an old browserctl meets a new artifact (or vice
versa).

A versioning convention also has to be cheap. browserctl writes a lot of
small artifacts; whatever we ship has to add bytes and lines of code in the
single digits, not require a schema registry or a migration framework.

## Decision

Every persisted browserctl artifact declares an integer **format version**
as the first thing in its payload. Every reader checks the header before
parsing the rest. Unknown versions are rejected with a typed error, never
parsed best-effort.

### The header

- **Plaintext / JSONL artifacts** start with `version: <int>\n` as the very
  first line. `Browserctl::FormatVersion.stamp(version: N)` produces the
  string; `Browserctl::FormatVersion.parse(io_or_string)` reads it back.
- **Manifest-shaped artifacts** (the `.bctl` bundle) carry `format_version:
  <int>` as the first key of the manifest.
- Versions are non-negative integers, start at `1`, and only go up.
  Floats, semver strings, and dates are out.

`lib/browserctl/format_version.rb` is the single source of truth for the
plaintext header.

### Per-format scope

Each persisted format owns its own version line:

| Format        | Surface                                   | Constant                                            |
| ------------- | ----------------------------------------- | --------------------------------------------------- |
| State bundle  | `format_version` first key of manifest    | `Browserctl::State::Bundle::BUNDLE_FORMAT_VERSION`  |
| Recording log | `_meta` JSONL line, `format_version` key  | `Browserctl::Recording::RECORDING_FORMAT_VERSION`   |
| Workflow file | `# format_version: N` Ruby comment header | `Browserctl::WORKFLOW_FORMAT_VERSION`               |
| Drift report  | `version: <int>` first line               | report writer constant                              |

Versions are **per format**, not global. Bumping the bundle format does not
touch the recording format. This keeps the blast radius of a format change
proportional to the change.

The constants are mirrored in a table in
[`docs/reference/format-versions.md`](../../reference/format-versions.md);
a drift guard fails CI if the doc and the constants disagree.

### Strict rejection on unknown version

A reader that opens an artifact whose declared version is not in its
`SUPPORTED_FORMAT_VERSIONS` array raises
[`Browserctl::ProtocolMismatch`](../../reference/errors.md), the CLI exits
[`5`](../../reference/exit-codes.md), and no further parsing happens. There
is no "try the latest parser and see what we get."

The one carve-out is workflow files. Workflows are human-authored Ruby; a
loader that refuses to run a workflow because its top-of-file comment says
`format_version: 0` would be more annoying than useful. The workflow loader
warns to stderr and proceeds. Bundles and recordings — both written by
browserctl itself — keep the strict gate.

### Migration path

`Browserctl::Migrations` (`lib/browserctl/migrations.rb`) is a process-wide
registry of one-hop upgraders. Each entry says "for format `F`, version
`N → N+1` is this block." `browserctl migrate <path>` detects the format
from the file extension, reads the declared version, finds a chain to the
target via BFS, and runs each hop in order.

The registry **ships empty in v0.12**. There is nothing to migrate yet —
every shipping format is at v1. The plumbing exists now so the operator
invocation (`browserctl migrate <path>`) is stable on the day a real
migration lands. Registering the first migration is then a single
`Browserctl::Migrations.register` call plus tests.

This split is deliberate. The strict reader gate
(`verify_format_version!`) and the migration command are separate: readers
never silently upgrade in place, and `migrate` is the only blessed mutation
path.

## Alternatives Considered

### SemVer per format
- **Pros**: Familiar; encodes additive vs. breaking changes.
- **Cons**: Three-part versions force us to articulate "minor" and "patch"
  semantics for binary file formats where the only interesting question is
  "can this reader handle this file." That question is binary; SemVer
  pretends it is ternary.
- **Why not**: Heavier vocabulary than the problem needs. A monotonic
  integer answers the only question we actually ask at the gate.

### No version header; sniff structure
- **Pros**: Zero bytes per artifact. No stamping logic.
- **Cons**: Format evolution becomes detective work. Every reader grows a
  branch per historical layout, sniffing increases coupling between writer
  and reader, and "we can't tell what version this file is" is itself a
  failure mode.
- **Why not**: The whole point of approaching 1.0 is being able to evolve
  formats with confidence. A header is one line; not having one costs us
  the ability to change formats without fear.

### Magic-byte sniffing per format
- **Pros**: Common in binary file formats; cheap.
- **Cons**: Magic bytes identify *what* a file is, not *which version* it
  is. We already know what a file is (we opened it from a known path);
  what we need is which version, and a magic byte does not tell us that
  without tipping into pseudo-versioning.
- **Why not**: Solves a problem we don't have and dodges the one we do.

### One global browserctl format version
- **Pros**: One number to track.
- **Cons**: Bumping the bundle layout would force a recording bump it does
  not need, and vice versa. Coupled versions produce coupled migrations
  and discourage small format changes.
- **Why not**: Per-format versions let each format evolve at its own pace.

### Defer until 1.0
- **Pros**: No work today.
- **Cons**: Every artifact already in the field at 1.0 would lack a
  header, forcing the 1.0 reader to special-case "no header" as "v0", which
  is the convention this ADR adopts — just shipped late and under
  duress.
- **Why not**: Cheaper to stamp from v0.12 onward and arrive at 1.0 with a
  uniform field.

## Consequences

### Positive

- **Failure modes are clear.** A version mismatch is a typed error with a
  documented exit code. Agents and humans both get the same signal: this
  artifact is not for this build of browserctl.
- **Formats can evolve post-1.0.** A bundle layout change is a constant
  bump, a writer change, a reader branch, and a migration registration —
  all mechanical, all isolated.
- **Cost is one line per artifact.** The header is `version: 1\n` or one
  manifest key. Reader cost is one line parse before the existing parse
  logic runs.
- **One operator entry point.** `browserctl migrate <path>` works for
  every format, today and going forward, even though the registry is empty.

### Negative

- **One more thing to remember when adding a new format.** Adding a fifth
  persisted format means adding a constant, a `SUPPORTED_FORMAT_VERSIONS`
  array, a `verify_format_version!` call site, an entry in
  `format-versions.md`, and a row in `Migrations::FORMAT_EXTENSIONS`. The
  drift guard catches the doc gap; nothing catches the others except
  review.
- **Pre-v0.12 recordings are now unreadable.** Old recordings have no
  header; the strict reader rejects them with `PROTOCOL_MISMATCH`. Listed
  as a breaking change in the v0.12 changelog with a documented one-time
  fix.

### Risks

- **Empty registry temptation.** With no migrations registered, it is
  tempting to keep evolving formats and "fix it later." Mitigation: the
  bumping checklist in `format-versions.md` makes registering the
  migration a step in the same PR that changes the format.
- **Workflow warn-only path could mask real breakage.** A workflow file
  with a future `format_version` will warn and load, and Ruby may then
  raise on an unknown DSL method. The warning is the load-bearing signal;
  if it gets ignored, the failure looks like a regular workflow bug.
  Acceptable for a human-authored format; we revisit if it bites in
  practice.

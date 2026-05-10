# Format versions

> Status: convention. Per-format adoption lands in WS-1 PRs #2–#4.

browserctl persists several artifacts to disk. To let formats evolve without
breaking historical data, every persisted artifact declares its format version
on the very first line:

```
version: <int>
```

For binary or manifest-shaped formats (e.g. `.bctl` bundles), the same field
appears as the **first key** of the manifest (`format_version: <int>`). Same
convention, different surface.

## The convention

- Every browserctl writer stamps `version: <int>\n` (or `format_version`) as
  the very first thing it writes.
- Every browserctl reader parses the version header **before** parsing the
  rest. If the version is unknown, the reader raises a typed
  `PROTOCOL_MISMATCH` error (see [error reference][errors] — landing in WS-2,
  PR #7) rather than attempting a best-effort parse.
- Versions are non-negative integers. They start at `1` and only go up.

`Browserctl::FormatVersion` (`lib/browserctl/format_version.rb`) is the single
source of truth for the convention:

- `Browserctl::FormatVersion.stamp(version: 1)` → `"version: 1\n"`.
- `Browserctl::FormatVersion.parse(io_or_string)` → `Integer`, or raises
  `Browserctl::ProtocolMismatch`.

## Tracked formats

| Format         | File pattern                        | Current version | Source of truth (post-WS-1)          |
| -------------- | ----------------------------------- | --------------- | ------------------------------------ |
| State bundle   | `*.bctl` manifest                   | `1` (live)      | `lib/browserctl/state/bundle.rb`     |
| Recording log  | `recordings/<session>.jsonl`        | `1` (live)      | `lib/browserctl/recording.rb`        |
| Workflow file  | `workflows/*.rb` (front-matter)     | `1` (live)      | `lib/browserctl/workflow.rb`         |
| Drift report   | `drift-*.json`                      | `1` (reserved)  | `lib/browserctl/replay/` (PR #3)     |
| Daemon state   | `~/.browserctl/state.json`          | `1` (reserved)  | `lib/browserctl/state.rb` (PR #2)    |

The `version` value above is *reserved* in this PR — wiring lands per
format in PRs #2–#4. The convention applies the moment a writer stamps it.

## Bumping a version

Bump the integer when the format changes in a way an older reader cannot
handle. That includes:

- Removing or renaming a required field.
- Changing the meaning, type, or units of an existing field.
- Reordering positional records.

Adding a purely optional field that older readers can ignore does **not**
require a bump.

When you bump a version:

1. Update the writer to stamp the new integer.
2. Update the reader to accept both old and new versions, dispatching to the
   right parse path.
3. Register a forward migration with `Browserctl::Migrations` (lands in WS-1
   PR #5). `browserctl migrate <path>` runs registered upgraders.
4. Update the table above and add a CHANGELOG entry under `### Breaking`.

## Workflow files: warn, don't raise

Workflow files (`*.rb` under `.browserctl/workflows/` or
`~/.browserctl/workflows/`) are the one exception to the hard-failure
rule. They declare their version in a top-of-file Ruby comment:

```ruby
# frozen_string_literal: true
# format_version: 1

Browserctl.workflow "login" do
  ...
end
```

The loader (`Browserctl::Runner#load_workflow_file`) calls
`Browserctl.verify_workflow_format_version!` before `load`-ing the
file. If the header is missing or declares an unsupported version, the
loader emits a `[browserctl]` warning to stderr and proceeds to load
the file anyway. This is deliberate: workflows are human-authored
Ruby, and the cost of refusing to run a slightly-stale workflow is
worse than the cost of loading it and letting Ruby raise on real
incompatibility.

Bundles, recordings, and (future) drift reports keep the strict
`PROTOCOL_MISMATCH` behaviour described below.

## Migration registry

`Browserctl::Migrations` (`lib/browserctl/migrations.rb`) is the registry
of upgraders that move an artifact written by an older browserctl up to
the current build's format version. Operators trigger it with:

```
browserctl migrate <path> [--to-version N] [--dry-run]
```

- The CLI detects the format from the file extension (`.bctl` →
  `:bundle`, `.jsonl` → `:recording`, `.rb` → `:workflow`), reads the
  declared `format_version`, and chains registered migrations from the
  current version up to `--to-version` (or the latest registered target).
- `--dry-run` prints the plan and exits without rewriting the file.
- On a current-version artifact the command is a no-op and exits 0:
  `No migrations registered for <format> v<n>; nothing to do.`
- Unknown format or no chain to the target exits with
  `PROTOCOL_MISMATCH` (exit code 5).

Registering a migration:

```ruby
Browserctl::Migrations.register(format: :bundle, from_version: 1, to_version: 2) do |path:, **|
  # Read `path`, transform, write back at v2.
end
```

The block is responsible for rewriting the file in place. The registry
handles ordering and chains hops via BFS, so you only register one
upgrader per adjacent version pair (`1 → 2`, `2 → 3`, …) — `migrate`
walks the chain.

`Browserctl::Migrations` is **separate** from
`verify_format_version!` (in bundle/recording/workflow). The latter
stays strict: a reader that encounters an unknown version raises
`PROTOCOL_MISMATCH`. `migrate` is the only blessed path to mutate an
old artifact in place.

**The registry ships empty in v0.12.** The first real migration arrives
only when a format actually changes post-1.0. The plumbing exists now
so the operator invocation is stable the day a real migration lands.

## Unknown-version error

A reader that encounters a version it does not recognise raises
`Browserctl::ProtocolMismatch` with code `PROTOCOL_MISMATCH`. The CLI maps
this to a dedicated exit code (assigned in WS-2 PR #10).

This is deliberately a hard failure: silently doing something with data we
don't understand is exactly the kind of bug `version: <int>` exists to
prevent.

[errors]: ./api-stability.md

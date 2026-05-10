# Format versions

browserctl persists several artifacts to disk. To let those formats evolve
without breaking historical data, every persisted artifact declares an integer
**format version** in its first byte of payload, and every reader checks that
header before parsing the rest.

This page is the single reference for which formats exist, what version each
is at today, and how to bump one without breaking older artifacts in the
field.

## The convention

- Every browserctl writer stamps a format-version header as the very first
  thing it writes. Plaintext artifacts use `version: <int>\n`. Manifest-shaped
  artifacts (`.bctl` bundles) use `format_version: <int>` as the first key of
  the manifest. Same convention, two surfaces.
- Every browserctl reader parses the version header **before** parsing the
  rest. If the version is unknown, the reader raises
  [`PROTOCOL_MISMATCH`](errors.md) — exit code [`5`](exit-codes.md) — rather
  than attempting a best-effort parse.
- Versions are non-negative integers. They start at `1` and only go up.

`Browserctl::FormatVersion` (`lib/browserctl/format_version.rb`) is the single
source of truth for the plaintext header:

- `Browserctl::FormatVersion.stamp(version: 1)` → `"version: 1\n"`.
- `Browserctl::FormatVersion.parse(io_or_string)` → `Integer`, or raises
  `Browserctl::ProtocolMismatch`.

## Tracked formats

| Format          | File pattern                    | Current version | Source constant                                  | On unknown version |
| --------------- | ------------------------------- | --------------- | ------------------------------------------------ | ------------------ |
| State bundle    | `*.bctl` manifest               | `1`             | `Browserctl::State::Bundle::BUNDLE_FORMAT_VERSION`     | strict — `PROTOCOL_MISMATCH` |
| Recording log   | `recordings/<session>.jsonl`    | `1`             | `Browserctl::Recording::RECORDING_FORMAT_VERSION`      | strict — `PROTOCOL_MISMATCH` |
| Workflow file   | `.browserctl/workflows/*.rb`    | `1`             | `Browserctl::WORKFLOW_FORMAT_VERSION`                  | warn-only — load proceeds |

Each row's "Current version" matches the constant in the source column. A
drift guard (`spec/docs/format_versions_md_spec.rb`) fails CI if the table
falls out of sync with the constants.

### Read-flow vs operator-flow

Two different gates use the version header, and they are intentionally split:

- **Read flow** — `verify_format_version!` (in `state/bundle.rb` and
  `recording.rb`) is **strict**. A reader that opens an artifact with an
  unsupported version raises `Browserctl::ProtocolMismatch` and the CLI exits
  `5`. There is no silent fallback.
- **Operator flow** — `browserctl migrate <path>` is the only blessed path
  to mutate an old artifact in place. It detects the format from the file
  extension, reads the declared version, and runs the registered chain of
  upgraders to bring the file up to the current version.

### Workflows: warn, don't raise

Workflow files are the one carve-out from the strict rule. They declare their
version in a top-of-file Ruby comment:

```ruby
# frozen_string_literal: true
# format_version: 1

Browserctl.workflow "login" do
  # ...
end
```

`Browserctl.verify_workflow_format_version!` runs before the loader `load`s
the file. If the header is missing or declares an unsupported version, the
loader emits a `[browserctl]` warning to stderr and proceeds to load anyway.

The reasoning: workflows are human-authored Ruby. Refusing to run a
slightly-stale workflow is worse than loading it and letting Ruby raise on
real incompatibility. Bundles and recordings — both written by browserctl
itself — keep the strict gate.

## Bumping a version

Bump the integer when the format changes in a way an older reader cannot
handle:

- Removing or renaming a required field.
- Changing the meaning, type, or units of an existing field.
- Reordering positional records.

Adding a purely optional field that older readers can ignore does **not**
require a bump.

When you bump a version:

1. **Update the constant.** Increment `BUNDLE_FORMAT_VERSION`,
   `RECORDING_FORMAT_VERSION`, or `WORKFLOW_FORMAT_VERSION` and add the new
   integer to the corresponding `SUPPORTED_FORMAT_VERSIONS` array (keep the
   old version listed if this build still reads it).
2. **Update the writer** to stamp the new integer.
3. **Update the reader** to dispatch on the version (old vs. new parse path).
4. **Register a migration** with `Browserctl::Migrations.register` for the
   `N → N+1` hop. `browserctl migrate <path>` walks the chain.
5. **Update tests** — every format has a roundtrip spec and a
   `verify_format_version!` spec; both need a new-version case.
6. **Update the table above** — the drift guard will fail CI otherwise.
7. **Add a CHANGELOG entry** under `### Breaking`.

## Migration registry

`Browserctl::Migrations` (`lib/browserctl/migrations.rb`) is the registry of
upgraders that move an artifact written by an older browserctl up to the
current build's format version. Operators trigger it with:

```
browserctl migrate <path> [--to-version N] [--dry-run]
```

- The CLI detects the format from the file extension (`.bctl` → `:bundle`,
  `.jsonl` → `:recording`, `.rb` → `:workflow`), reads the declared
  `format_version`, and chains registered migrations from the current version
  up to `--to-version` (or the latest registered target).
- `--dry-run` prints the plan and exits without rewriting the file.
- On a current-version artifact the command is a no-op and exits `0`:
  `No migrations registered for <format> v<n>; nothing to do.`
- An unknown format, an unreadable version header, or no chain to the target
  raises [`PROTOCOL_MISMATCH`](errors.md) — exit code [`5`](exit-codes.md).

Registering a migration:

```ruby
Browserctl::Migrations.register(format: :bundle, from_version: 1, to_version: 2) do |path:, **|
  # Read `path`, transform, write back at v2.
end
```

The block rewrites the file in place. The registry handles ordering and
chains hops via BFS, so you only register one upgrader per adjacent version
pair (`1 → 2`, `2 → 3`, …).

**The registry ships empty in v0.12.** The first real migration arrives only
when a format actually changes post-1.0. The plumbing exists now so the
operator invocation is stable the day a real migration lands. See the source
at [`lib/browserctl/migrations.rb`](../../lib/browserctl/migrations.rb).

## See also

- [`errors.md`](errors.md) — full error-code reference, including
  `PROTOCOL_MISMATCH`.
- [`exit-codes.md`](exit-codes.md) — exit `5` is reserved for protocol
  mismatch.
- [`debugging.md`](../guides/debugging.md) — how to inspect a stale artifact
  before deciding to migrate or discard it.

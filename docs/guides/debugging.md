# Debugging browserctl

When something goes wrong — a workflow exits non-zero, the daemon dies, a snapshot returns nothing — browserctl gives you three local tools to figure out why: structured JSONL logs, the `browserctl trace` timeline, and crash reports. None of them phone home.

This guide walks the typical loop: **trace → crash report → file an issue**.

## When something doesn't work

Three steps, in order:

1. **Check the exit code.** `browserctl` returns a non-zero exit code for failures. The [exit codes reference](../reference/exit-codes.md) lists what each one means.
2. **Run `browserctl trace`** to see a chronological timeline of recent CLI + daemon activity. This is usually enough to pinpoint the failing step.
3. **If the daemon crashed**, look for a crash report in `~/.browserctl/logs/crash-*.json` and attach it to your issue.

## Reading a trace

### Where the logs live

The daemon and CLI write structured JSON Lines (one record per line) to:

```
~/.browserctl/logs/daemon.log
~/.browserctl/logs/cli.log
```

Files rotate at 10 MB and the last 10 are kept. Each record looks like:

```json
{"ts":"2026-05-10T14:22:11.034Z","level":"INFO","component":"daemon","event":"snapshot.captured","session_id":"s_abc","bytes":12048}
```

You can grep them directly, but `browserctl trace` is friendlier.

### `browserctl trace`

```
browserctl trace [<session>] [--no-redact]
```

With no arguments, `trace` merges `cli.log` and `daemon.log`, sorts by timestamp, and prints a one-line-per-event timeline. Sample output:

```
14:22:10.998 . INFO  cli     session.create         session_id=s_abc
14:22:11.034 S INFO  daemon  snapshot.captured      session_id=s_abc bytes=12048
14:22:11.210 N INFO  daemon  navigate               url=https://example.com
14:22:11.512 ! ERROR daemon  driver.timeout         session_id=s_abc after_ms=30000
```

The single-character category icon comes from inspecting record keys:

| Icon | Category | Trigger |
|---|---|---|
| `!` | error | `level == "ERROR"` or `error` key present |
| `S` | snapshot | `snapshot` key present |
| `N` | network | `request`, `response`, or `url` key present |
| `.` | event | anything else |

### Filtering by session

Pass a session id positionally to scope the timeline:

```bash
browserctl trace s_abc
```

When no filter is given and records carry `session_id`, `trace` defaults to the most recent session it sees. **Current limitation:** not every log line is stamped with `session_id` yet — when no records carry one, `trace` shows the entire merged stream. If your output mixes sessions, scope by tailing/rotating logs or by timestamp.

## Redaction (it's on by default)

Traces redact known secret values before they hit your terminal. The replacement marker is the literal `[REDACTED]`.

What gets redacted:

1. **Environment variables** whose names match `*_TOKEN`, `*_KEY`, `*_SECRET`, `*_PASSWORD`. Their *values* are scrubbed wherever they appear in the trace.
2. **Secrets resolved at runtime** by `SecretResolverRegistry` — values your workflows asked browserctl to fetch during this process.

Values shorter than 4 characters are skipped (too noisy to redact safely).

### Replay limitation

When you run `trace` against logs from a previous daemon process, the in-memory secret registry is gone — only **current ENV patterns** apply. If you've rotated a secret since the log was written, the old value won't be redacted. Skim the output before pasting it anywhere public.

### `--no-redact`

For local debugging only:

```bash
browserctl trace --no-redact
```

`trace` prints a stderr warning when this flag is set:

```
[browserctl] traces include unredacted secret values; do not paste this output publicly.
```

**Always run with default redaction before pasting trace output into an issue, Slack, or chat.**

## Crash reports

When `browserd` hits an unhandled exception, it writes a single JSON file to `~/.browserctl/logs/` named `crash-<timestamp>.json` and re-raises. The file mode is `0600`.

Shape (truncated):

```json
{
  "schema_version": 1,
  "ts": "2026-05-10T14:22:11.500Z",
  "daemon_version": "0.12.0",
  "ruby_version": "3.3.0",
  "os": { "platform": "arm64-darwin25", "sysname": "Darwin", "version": "..." },
  "error": { "class": "RuntimeError", "message": "..." },
  "backtrace": ["lib/browserctl/server.rb:42:in ...", "..."],
  "last_events": [
    { "ts": "...", "level": "INFO", "component": "daemon", "event": "..." }
  ]
}
```

`last_events` is a tail of the most recent ~50 JSONL records from `daemon.log` to give the report context.

The daemon also prints a hint at startup so you don't have to remember the path:

```
browserd starting — log: ~/.browserctl/logs/daemon.log
  if browserd crashes, attach the crash report from ~/.browserctl/logs/crash-*.json
```

### Known limitation: crash reports are not redacted

Unlike `browserctl trace`, the crash writer does **not** scrub secret values from `error.message`, `backtrace`, or `last_events`. Open the JSON file and review it before attaching to a public issue. Redaction of crash reports is tracked as a follow-up — see the v0.12 milestone.

### Attaching to a GitHub issue

GitHub accepts JSON files as attachments via drag-and-drop on the issue editor. If the file is sensitive or large, paste the relevant parts inline inside a fenced ` ```json ` block instead.

## Filing a good issue

Before you click submit, check that you have:

- [ ] **`browserctl --version`** output.
- [ ] **Reproduction steps** — the exact commands you ran, in order.
- [ ] **`browserctl trace` output**, default redaction on. Skim it first.
- [ ] **Crash report** (if the daemon crashed) — opened, reviewed for secrets, attached.
- [ ] **OS + Ruby version** (the crash report carries these; otherwise mention them).

A short, redacted trace plus a reviewed crash report covers most bug reports without a back-and-forth.

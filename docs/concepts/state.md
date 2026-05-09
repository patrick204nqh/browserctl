# State

A browser session is more than a tab. It's the cookies the server set, the tokens the page wrote into `localStorage`, the CSRF salt cached in `sessionStorage`, and the chain of origins those things belong to. Lose any one of them and the next request looks like a stranger.

browserctl treats all of that as one thing: **state**. One verb saves it, one loads it, one bundle on disk holds it.

```
~/.browserctl/state/<name>.bctl
```

A `.bctl` is a single, portable file: a plaintext manifest (origins, flow binding, expiry) plus a payload (cookies + storage), HMAC-signed and optionally passphrase-encrypted. You can copy it between machines, push it to S3, hand it to a teammate over 1Password — and the receiving side validates it byte-for-byte.

---

## The verb

```bash
browserctl state save   <name> [--encrypt] [--origins a,b] [--flow NAME]
browserctl state load   <name>
browserctl state list
browserctl state info   <name>
browserctl state delete <name>
browserctl state rotate <name> [--params FILE] [--key value ...]
browserctl state export <name> <destination>     # file path, s3://..., op://Vault/Item
browserctl state import <source> [--name NAME]
```

That's the whole surface. Everything below is just what each verb does and why.

---

## Save

```bash
browserctl page open work --url https://github.com
# ...log in by hand, or via a flow...
browserctl state save github --flow github_login
```

What gets captured:

| | Source | Why |
|---|---|---|
| Cookies | All cookies from all open pages | The default auth currency for most sites |
| `localStorage` | Per-origin, all open pages | Tokens, feature flags, persisted UI state |
| `sessionStorage` | Per-origin, all open pages | CSRF salts, ephemeral tokens — kept for completeness; not all sites restore cleanly |
| Origins | Auto-detected from cookie domains + `location.origin` of every open page | Used by `state info`, lets `state load` know where to seed `localStorage` |
| Flow binding | `--flow NAME` | Tells `state rotate` and (in v0.10+) `load_state` how to refresh the bundle when it expires |

`--encrypt` adds a passphrase. The payload is encrypted with AES-256-GCM; the manifest stays plaintext so `state info` can show origins and expiry without prompting.

`--origins a,b` overrides auto-detection. Use it when the default is wrong (cookieless auth, single-page apps that talk to many origins from one tab).

---

## Load

```bash
browserctl state load github
```

Restores cookies on the current page, then visits each origin once and replays its `localStorage` keys. `sessionStorage` is **not** restored — it's tab-scoped by spec and most sites that depend on it tolerate it being empty after a fresh tab.

If the bundle was encrypted, you'll be prompted for the passphrase (or set `BROWSERCTL_STATE_PASSPHRASE`).

---

## Info

```bash
$ browserctl state info github
{
  "ok": true,
  "info": {
    "name": "github",
    "version": 1,
    "producer": "browserctl/0.10.0",
    "created_at": "2026-05-09T08:30:00Z",
    "origins": ["https://github.com", "https://api.github.com"],
    "flow": "github_login",
    "expires_at": "2026-08-07T08:30:00Z",
    "encrypted": false,
    "size": 2048
  }
}
```

Reads the manifest only. No passphrase needed even for encrypted bundles — that's the point of keeping the manifest plaintext.

`expires_at` is the **earliest** cookie expiry. When the daemon detects an `AUTH_REQUIRED` (v0.10+ WS-5), the soonest-expired cookie is usually why.

---

## Rotate

```bash
browserctl state rotate github
```

Looks up the bound flow from the manifest, runs it against the daemon, and re-saves the bundle with the same origins and a refreshed `flow_version`. This is what `load_state` calls under the hood when it finds an expired bundle (v0.10+ WS-5).

Errors when:
- the manifest has no flow binding — re-save with `state save --flow NAME`
- the bound flow isn't in the registry — `browserctl flow list` to confirm

---

## Export and import

`.bctl` is a single file — moving it is `cp`. The transports give you that as a CLI verb and add cloud destinations:

```bash
browserctl state export github ./github.bctl
browserctl state export github s3://my-bucket/states/github.bctl
browserctl state export github op://Engineering/github-state

browserctl state import ./github.bctl
browserctl state import s3://my-bucket/states/github.bctl --name github-prod
```

Bundle bytes go over the wire verbatim — no re-encoding — so the receiving side validates the original HMAC/digest. Imports check the magic header before persisting; an invalid blob never lands in your state directory.

Add your own transport by registering a class with `Browserctl::State::Transport.register` (see `lib/browserctl/state/transport.rb`).

---

## State vs session vs cookie

You'll see three commands in the help text. Reach for them in this order:

1. **`state *`** — what you want 99% of the time. One file, all the auth pieces, encryption optional, transports built in, refresh via flow binding.
2. **`session *`** — the v0.8 ancestor. Per-name directory under `~/.browserctl/sessions/` with split files for cookies, localStorage, sessionStorage, and metadata. Still works, still supported, but `state` is what new code should use. (v0.10 deprecation warning; removal not before v0.12.)
3. **`cookie *` and `storage *`** — escape hatches. Reach for these when you need to set a single cookie, dump localStorage to JSON for an external diff tool, or otherwise operate below the bundle layer. Most workflows shouldn't touch them.

---

## When `.bctl` isn't enough

- **State the site refuses to expose to JS** — HTTP-only cookies are captured (CDP gives them up), but anything stored in IndexedDB isn't yet. Tracked under v0.10 WS-4 follow-ups.
- **Cross-profile bundles** — a bundle is tied to the origins it captured. Loading a github.com bundle into a daemon that's about to talk to gitlab.com is harmless but useless.
- **Long-lived secrets you'd rather not have on disk** — encrypt with `--encrypt` (passphrase via env or stdin), or export to `op://` and re-import on demand.

---

## See also

- [Flows](flows.md) — what produces state, what `state rotate` re-runs
- [Sessions and Pages](sessions-and-pages.md) — the daemon model the state lives inside
- [`docs/architecture/decisions/0014-bctl-bundle-format.md`](../architecture/decisions/) — wire format, encryption, transport interface (after WS-4 lands)

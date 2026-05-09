# ADR-0014: `.bctl` Bundle Format — HMAC-then-Encrypt, Manifest, Transports, Origin Scope

**Date**: 2026-05-09
**Status**: accepted
**Extends**: ADR-0008 (session persistence). The `.bctl` bundle replaces the v0.8 session zip as the canonical portable format.
**Deciders**: Patrick

## Context

v0.8/v0.9 stored auth state as a zip of cookies + storage with optional passphrase encryption. Three problems surfaced as flows landed:

1. **No metadata layer.** A zip on disk had no record of which origins it covered, which flow produced it, or when it was made. `state info` had nothing to read.
2. **All-or-nothing encryption.** A passphrase-protected zip is opaque — you couldn't see what's inside without unlocking it. That made `state list` and `state info` either useless (skip the file) or insecure (decrypt to inspect).
3. **No transport story.** Moving a session between machines meant `cp`. There was no shared abstraction for `s3://` or `op://`.

v0.10 needs a single file format that carries enough metadata to be inspectable without unlocking, signs payload integrity even when not encrypted, and is movable through pluggable transports.

## Decision

Define `.bctl` — a single-file binary format with a plaintext manifest header, an optional encrypted payload, and a signed footer. Implementation: `lib/browserctl/state/bundle.rb`.

### Wire format

```
magic:        "BCTL\x00"           5 bytes
version:      0x01                 1 byte
flags:        bit 0 = encrypted    1 byte
reserved:     0x00                 1 byte
manifest_len:                      4 bytes (big-endian)
manifest:     JSON bytes           manifest_len bytes (always plaintext)
payload_len:                       4 bytes (big-endian)
payload:      see below            payload_len bytes
footer:       32 bytes
```

**Plaintext payload** (`flags & 0x01 == 0`):
- `payload` is JSON bytes for cookies + storage.
- `footer` is `SHA-256(magic || ... || payload)` — corruption check, not a signature.

**Encrypted payload** (`flags & 0x01 == 1`):
- `payload = salt(16) || nonce(12) || ciphertext || tag(16)`.
- Keys derived via `PBKDF2(passphrase, salt, 200_000, SHA-256, 64-byte output)`. First 32 bytes = AES-256-GCM key. Last 32 bytes = HMAC-SHA-256 key.
- `footer` is `HMAC-SHA-256(hmac_key, magic || ... || payload)`.

### HMAC-then-encrypt (encrypt-then-MAC, more precisely)

The MAC covers the ciphertext, not the plaintext. This is encrypt-then-MAC — the standard composition that prevents an attacker from feeding crafted ciphertext through the AES-GCM path before integrity is verified.

The manifest is part of the MAC input even though it's plaintext. Tampering with the manifest (e.g. swapping a `flow_version`, dropping origins) invalidates the footer, so an attacker cannot rewrite the manifest without the passphrase.

GCM already authenticates the ciphertext under its own tag, so the outer HMAC is technically redundant for the encrypted payload itself. The reason for the outer HMAC: it covers the **manifest + magic + version + flags + payload boundaries**, not just the ciphertext. A bare GCM tag would let someone replace the manifest in a stored bundle without detection.

### Manifest layout

```json
{
  "name": "github",
  "created_at": "2026-05-09T12:30:00Z",
  "browserctl_version": "0.10.0",
  "flow": "github_login",
  "flow_version": "0.1.0",
  "origins": ["https://github.com", "https://api.github.com"],
  "expires_hint": "2026-05-16T12:30:00Z"
}
```

- `flow` and `flow_version` enable auto-rotate: `load_state` → AUTH_REQUIRED uses `flow` as the `suggested_flow`. `flow_version` drives the runtime version check from ADR-0013.
- `origins[]` defaults to the navigation chain captured during the producing flow's `produces_state` block. `state save --origins a,b,c` overrides. Inspectable without a passphrase.
- `expires_hint` is advisory — the truth lives in the cookies' own expiry. Used by `state info` for human-readable summaries.

### Origin scoping default

Origin scope defaults to **auto-detected from the producing flow's navigation chain**. The flow's `produces_state` block records every URL navigated during the run; their origins (scheme + host) become the bundle's `origins[]`.

`state save --origins a,b,c` overrides for the rare case where the flow navigates to an interstitial origin that should not be persisted (e.g. an OAuth provider during `oauth_github`).

`state info <name>` always surfaces the captured origins. There is no separate "did you mean to save these origins?" prompt — the bundle is a record of what happened, with explicit override available.

### Transport interface

`Browserctl::State::Transport` is a registry of URI-scheme-to-transport mappings:

```
.scheme            String — "file", "s3", "op", ...
#handles?(uri)     Boolean
#available?        Boolean — CLI/network preflight
#read(uri)         binary String
#write(uri, blob)  nil; raises State::Transport::TransportError on failure
```

Bare paths with no scheme fall through to `FileTransport`. v0.10 ships `file`, `s3` (via aws CLI), and `op` (via 1Password CLI).

Transports are responsible only for moving bytes — they never inspect or modify the bundle. A passphrase-protected bundle stays passphrase-protected end-to-end; the transport layer has no key material.

## Alternatives Considered

### Keep using zip, add a sidecar `.json` manifest
- **Pros**: Zero format work; manifest stays inspectable.
- **Cons**: Two files to keep in sync; encryption applies to one but not the other; no atomicity on copy.
- **Why not**: Two files for one logical artefact is a UX regression — `state export github /tmp/x` should produce one file.

### Encrypt-the-whole-thing, no plaintext header
- **Pros**: Maximum confidentiality.
- **Cons**: `state list`/`state info` need the passphrase to show anything — defeats their purpose.
- **Why not**: The cost of plaintext metadata is small (origins and timestamps are not secrets); the ergonomic win is large.

### MAC-then-encrypt
- **Pros**: Slightly stronger when AES-GCM is replaced.
- **Cons**: Forces decryption before integrity verification, opening up oracle attacks; standard composition order is encrypt-then-MAC.
- **Why not**: Cryptographic best practice favours encrypt-then-MAC.

### Origin scope = "all origins from cookies"
- **Pros**: No flow instrumentation needed.
- **Cons**: Cookies leak — third-party trackers, analytics, CDN cookies — none of which the user actually wants in their bundle. Result: noisy bundles.
- **Why not**: Auto-detected nav chain is a tighter, more semantic boundary.

## Consequences

### Positive

- One file, one format, one extension (`.bctl`).
- `state info` works without a passphrase.
- Bundle integrity is signed even in plaintext mode (corruption check) and authenticated in encrypted mode (HMAC).
- New transports (e.g. `gs://`, `azure://`) plug in without touching the bundle codec.
- Auto-rotate has everything it needs in the manifest — no separate "which flow produced this?" lookup.

### Negative

- New on-disk format means the existing v0.8 session zip is not interchangeable. There is no auto-migration script; users re-create bundles via `state save`. The old `session export`/`session import` commands continue to work for the v0.8 zip format through v0.10 with a deprecation warning.
- Manifest is plaintext, so origin lists and timestamps leak in transit. Acceptable: those are not secrets.

### Risks

- **PBKDF2 iteration count drift**. 200,000 is chosen for 2026-era hardware; a future ADR will revisit if the OWASP recommendation changes. Encoded inside `version: 0x01`, so a future bundle format can change derivation without breaking old readers.
- **Manifest schema growth**. Anything added to the manifest is plaintext forever (no way to encrypt it without breaking `state info`). Future fields must be reviewed for sensitivity.

# Compatibility Matrix

The narrow, defended support surface for browserctl through 0.x. Anything outside this matrix may work — there is no commitment.

## Supported

| axis | value |
|------|-------|
| Ruby | 3.4 |
| OS | macOS 14+ |
| Browsers | Chrome (stable), Chromium, Brave |

CI exercises exactly this combination — see `.github/workflows/ci.yml`. If something is not in CI, it is not supported.

## Why this narrow

This is a 0.x project run by a single maintainer. The cost of a wide compatibility matrix — extra CI minutes, extra failure modes, time spent triaging issues on platforms the maintainer can't reproduce — is real and not paid back at this stage. The matrix tightens here so the project can move faster on the v0.12 → 1.0 work.

The matrix will be reconsidered after 1.0, with a deprecation cadence documented in `api-stability.md`.

### Ruby 3.4 only

The gemspec floor stays at 3.3 so existing 3.3 users are not actively broken, but only 3.4 is exercised in CI. If 3.3 regresses, the fix lands when a user reports it; we don't catch it in CI. Anyone targeting older Rubies should pin browserctl to a release that explicitly tested against their Ruby.

### macOS 14+ only

CI runs on `macos-14` GitHub-hosted runners. Linux (Ubuntu) and Windows (WSL2) are dropped from CI. Browser/Ferrum behaviour does diverge between platforms, so:
- Linux/Windows users should expect to report breakage themselves; no maintainer-side smoke catches it.
- Issues filed against Linux/Windows are accepted but have no SLA.

The maintainer's daily-driver platform is macOS, so this is also where bugs are easiest to reproduce.

### Browsers

All three Chromium-family browsers run from the macOS Homebrew cask install paths. `brave` is marked soft in CI (failure does not fail the build) until the cask install path has been stable for several weeks.

## Drift policy

`docs/reference/compatibility.md` matches `.github/workflows/ci.yml` exactly. Any divergence is a bug — either the doc is stale, or CI is testing something we don't claim to support. Open an issue.

## Out of scope

- Linux / Ubuntu (dropped from CI through 0.x)
- Windows native or WSL2 (dropped from CI through 0.x)
- Ruby 3.2 and earlier (never in CI)
- Ruby 3.3 (gemspec-supported but not in CI — see above)
- macOS 13 and earlier (never in CI on this matrix)
- Firefox, Safari, WebKit (out of scope; the driver is CDP-only)

After 1.0, broaden as funded by either community contribution or sustained maintainer time.

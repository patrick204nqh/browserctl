# Compatibility Matrix

The narrow, defended support surface for browserctl through 0.x. Anything outside this matrix may work — there is no commitment.

## Supported

| axis | value |
|------|-------|
| Ruby | 3.4 |
| OS | Ubuntu (latest GitHub-hosted runner; `ubuntu-22.04` for the browser-replay job) |
| Browsers | Chrome (stable), Chromium, Brave |

CI exercises exactly this combination — see `.github/workflows/ci.yml`. If something is not in CI, it is not supported.

## Why this narrow

This is a 0.x project run by a single maintainer. The cost of a wide compatibility matrix — extra CI minutes, extra failure modes, time spent triaging issues on platforms the maintainer can't reproduce — is real and not paid back at this stage. The matrix tightens here so the project can move faster on the v0.12 → 1.0 work.

The matrix will be reconsidered after 1.0, with a deprecation cadence documented in `api-stability.md`.

### Ruby 3.4 only

The gemspec floor stays at 3.3 so existing 3.3 users are not actively broken, but only 3.4 is exercised in CI. If 3.3 regresses, the fix lands when a user reports it; we don't catch it in CI. Anyone targeting older Rubies should pin browserctl to a release that explicitly tested against their Ruby.

### Ubuntu only

CI runs on Ubuntu (`ubuntu-latest` and `ubuntu-22.04`) GitHub-hosted runners. macOS and Windows-via-WSL2 are out of CI. Browser/Ferrum behaviour does diverge between platforms, but Ubuntu is the cheapest GitHub-hosted runner family by an order of magnitude (≈10×) and is the closest match to the production targets browserctl gets deployed against (CI containers, headless servers).

Practical assumption: a build that passes on Ubuntu also works on a developer's macOS for everyday use. Bugs that show up only on macOS or Windows are accepted as user reports without an SLA.

### Browsers

Chromium-family only. All three are installed on Ubuntu CI:

- **Chrome** via `browser-actions/setup-chrome@v1` (stable channel).
- **Chromium** via `apt-get install chromium-browser`.
- **Brave** via the official Brave apt repo. Marked **soft** in CI — failure does not fail the build until the install path has been stable for several weeks.

## Drift policy

`docs/reference/compatibility.md` matches `.github/workflows/ci.yml` exactly. Any divergence is a bug — either the doc is stale, or CI is testing something we don't claim to support. Open an issue.

## Out of scope

- macOS in CI (unsupported through 0.x; should still work for development)
- Windows native or WSL2 (unsupported through 0.x)
- Ruby 3.2 and earlier (never in CI)
- Ruby 3.3 (gemspec-supported but not in CI — see above)
- Firefox, Safari, WebKit (out of scope; the driver is CDP-only)

After 1.0, broaden as funded by either community contribution or sustained maintainer time.

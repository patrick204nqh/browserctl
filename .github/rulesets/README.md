# Repository Rulesets

These JSON files define GitHub repository rulesets. They are stored as code for reproducibility but must be imported manually after the repository is made public.

## Files

| File | Target | Purpose |
|------|--------|---------|
| `main-branch.json` | `main` branch | Require PR + CI before merge; block force pushes |
| `release-tags.json` | `v*.*.*` tags | Prevent deletion or modification of release tags |

## How to import

1. Go to **Settings → Rules → Rulesets**
2. Click **New ruleset → Import a ruleset**
3. Upload `main-branch.json` — review and click **Create**
4. Repeat for `release-tags.json`

## Notes

- `main-branch.json` requires two CI checks to pass: `Lint` and `Test (Ruby 3.3)`. If the matrix in `ci.yml` is extended to cover more Ruby versions, add those check names here too.
- Repository admins can bypass the branch ruleset for emergency merges. The tag ruleset has no bypass — release tags are immutable once pushed.

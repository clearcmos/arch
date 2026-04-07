# CI/CD Reference - CurseForge Deployment

Complete setup guide for automated addon releases to CurseForge via GitHub Actions.

## Required GitHub Secrets

Each addon repo needs two secrets set via **Settings > Secrets and variables > Actions**:

| Secret | Description | Reusable? |
|--------|-------------|-----------|
| `CF_API_KEY` | CurseForge API token | Yes - same key works for all addons |
| `CURSEFORGE_PROJECT_ID` | Numeric project ID from CurseForge | No - unique per addon |

### Getting the values

- **CF_API_KEY**: Generate at https://authors-old.curseforge.com/account/api-tokens — one token works across all your projects
- **CURSEFORGE_PROJECT_ID**: Found on your addon's CurseForge page in the "About Project" sidebar (a number like `1459997`)

### Setting secrets via CLI

```bash
# Set secrets (same CF_API_KEY for all addons)
gh secret set CF_API_KEY --body "your-curseforge-api-token"
gh secret set CURSEFORGE_PROJECT_ID --body "1459997"

# Verify secrets are configured
gh secret list --json name
# Should show: [{"name":"CF_API_KEY"},{"name":"CURSEFORGE_PROJECT_ID"}]
```

**Note**: GitHub secrets are write-only — you cannot read back the values. If you lose your `CF_API_KEY`, generate a new one on CurseForge.

## Workflow File

`.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Needed for changelog generation

      - name: Package and Release
        uses: BigWigsMods/packager@v2
        with:
          args: -p ${{ secrets.CURSEFORGE_PROJECT_ID }}
        env:
          CF_API_KEY: ${{ secrets.CF_API_KEY }}
          GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}
```

**Critical**: `permissions: contents: write` is required at the top level. Without it, `GITHUB_TOKEN` can't create GitHub Releases (403 error). The CurseForge upload still succeeds, but the GitHub Release step fails.

## .pkgmeta File

Controls what gets packaged into the zip. The `ignore` list excludes files from the CurseForge upload:

```yaml
package-as: AddonName

manual-changelog:
  filename: CHANGELOG.md
  markup-type: markdown

ignore:
  - README.md
  - CHANGELOG.md
  - CI.md
  - CLAUDE.md
  - .github
  - .gitignore
  - .pkgmeta
  - assets
```

### What CurseForge receives

Only files NOT in the ignore list end up in the zip. Typically:
- `AddonName.lua` (and any other .lua files)
- `AddonName.toc`
- `LICENSE.md`
- Any `.xml` files
- Any `Libs/` directory

`CHANGELOG.md` is used by the packager to populate the CurseForge release notes, but is excluded from the zip itself.

## Release Process

```bash
# 1. Update version in .toc
## Version: 1.0.1

# 2. Update CHANGELOG.md with new version section

# 3. Commit
git add -A && git commit -m "feat: description of changes"

# 4. Tag and push
git tag v1.0.1
git push origin main --tags

# 5. Monitor the workflow
gh run list --limit 1
gh run view --log  # if you need details
```

## Game Version Detection

The packager reads `## Interface:` from the `.toc` to determine which game version to upload for:

| Interface Value | Game Version |
|----------------|--------------|
| `20505` | TBC Classic / Anniversary Edition |
| `11503` | Classic Era |
| `110002` | Retail |

## Optional: Multi-Platform Upload

To also upload to WoWInterface and Wago, add more secrets and update the workflow args:

```yaml
- name: Package and Release
  uses: BigWigsMods/packager@v2
  with:
    args: >-
      -p ${{ secrets.CURSEFORGE_PROJECT_ID }}
      -w ${{ secrets.WOWI_ADDON_ID }}
      -a ${{ secrets.WAGO_PROJECT_ID }}
  env:
    CF_API_KEY: ${{ secrets.CF_API_KEY }}
    WOWI_API_TOKEN: ${{ secrets.WOWI_API_TOKEN }}
    WAGO_API_TOKEN: ${{ secrets.WAGO_API_TOKEN }}
    GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}
```

## Troubleshooting

- **403 on GitHub Release**: Missing `permissions: contents: write` in workflow
- **Empty secret list**: Secrets not set — use `gh secret set`
- **Upload succeeds but wrong game version**: Check `## Interface:` value in `.toc`
- **Files missing from zip**: Check `.pkgmeta` ignore list
- **Changelog not showing on CurseForge**: Ensure `manual-changelog` section in `.pkgmeta` points to correct file

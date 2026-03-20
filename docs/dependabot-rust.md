# Dependabot for Rust Projects

How to set up automated dependency vulnerability scanning for Rust repos on GitHub.

## Setup

Add `.github/dependabot.yml` to the repo:

```yaml
version: 2
updates:
  - package-ecosystem: "cargo"
    directory: "/"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "deps"
```

That's it. Dependabot will open PRs when:
- A dependency has a known vulnerability (immediate)
- A dependency has a newer version available (weekly)

## CI Audit Workflow

Add `.github/workflows/audit.yml` for continuous checking:

```yaml
name: Security Audit
on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 0 * * 1'  # Weekly Monday midnight

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: rustsec/audit-check@v2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
```

This catches advisories published between Dependabot's weekly scans.

## Manual Checks

```bash
# Check for known vulnerabilities
cargo audit

# Update all deps to latest compatible versions
cargo update

# Check for outdated deps (needs cargo-outdated)
cargo outdated
```

## When to Run Manually

- Before tagging a release
- After adding new dependencies
- If you haven't touched the project in a while

## How It Works

- Dependabot uses the RustSec Advisory Database (https://rustsec.org)
- It monitors crates.io for new versions
- Vulnerability PRs are marked as security updates
- Version update PRs show changelogs

## Repos to Enable This On

- ~/git/monctl
- Any future Rust projects

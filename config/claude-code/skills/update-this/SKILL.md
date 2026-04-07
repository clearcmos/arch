---
name: update-this
description: Comprehensive documentation audit and update workflow for NixOS infrastructure. Use when user says "update-this", "audit docs", "update documentation", "docs are outdated", or "sync docs with codebase". Runs parallel agents to cross-reference CLAUDE.md and docs/ against the actual codebase, then applies fixes.
user-invocable: true
disable-model-invocation: false
metadata:
  author: nicholas
  version: 2.0.0
  category: workflow-automation
---

# Update-This: Documentation Audit & Sync

Systematically audits and updates all documentation (CLAUDE.md, docs/) to match the actual state of the NixOS codebase. Uses parallel research agents for speed, then applies atomic fixes.

**NOTE:** README.md is intentionally minimal (no infrastructure details). Do NOT add system info to it.
Docs live on NAS at `/mnt/syno/nextcloud/nixos/docs/`, symlinked at `/etc/nixos/docs/`.

## Instructions

### Step 1: Launch Parallel Audit Agents

Spawn 3 Explore agents concurrently to cross-reference documentation against the codebase:

**Agent 1 - CLAUDE.md Audit:**
- Cross-reference every port in the port registry against actual `.nix` files
- Verify every service marked active/disabled/removed matches reality
- Check all file paths mentioned still exist
- Check all commands and scripts mentioned still exist
- Report discrepancies with line numbers

**Agent 2 - System State + docs/README.md Audit:**
- Gather current system facts directly from source (NOT from README.md):
  - Kernel version: `uname -r`
  - Nixpkgs commit: `jq '.nodes.nixpkgs.locked.rev' /etc/nixos/flake.lock`
  - Nixpkgs unstable commit: `jq '.nodes.nixpkgs-unstable.locked.rev' /etc/nixos/flake.lock`
  - Secret count: `ls /etc/nixos/secrets/*.age | wc -l`
  - NixOS channel: check `flake.nix` branch reference (e.g., `nixos-25.05`)
- Cross-reference these facts against `docs/README.md`
- Check all services listed in `docs/README.md` are actually active
- Check for removed/disabled services still listed as active
- Verify timestamps (Last Updated, Last Security Review, etc.)
- Check architecture descriptions match current host configs in `hosts/*/default.nix`

**Agent 3 - Module State Audit:**
- List all modules in `modules/services/`, `modules/desktop/`, `modules/desktop/ai/`, `modules/desktop/gaming/`
- Check which are imported by each host in `hosts/*/default.nix`
- Identify active vs disabled vs archived modules
- Check `scripts/` directory for current scripts
- Check `apps/` directory for current apps
- Map complete port allocation from actual nix files

### Step 2: Review Git History

While agents run, also check:
```bash
# Commits since docs were last updated
git log --oneline --since="<CLAUDE.md last modified date>"

# Uncommitted changes
git diff --stat HEAD

# Recent feature additions
git log --oneline -30
```

This catches new features, removed services, and config changes that docs may have missed.

### Step 3: Compile Findings

Once all agents complete, compile a consolidated findings list organized by file:

- **CLAUDE.md issues**: port mismatches, stale service references, missing new services, outdated paths
- **docs/README.md issues**: timestamps, missing services in listings, outdated host roles, stale version numbers
- **docs/ issues**: missing docs for new features, stale docs for removed features
- **Code issues**: stale firewall ports, dead traefik routes, commented-out imports still in firewall

Present the findings summary to the user before making changes.

### Step 4: Apply Documentation Fixes

Create task list for tracking, then apply fixes in this order:

1. **CLAUDE.md** - Port registry, service status, file paths, Last Modified date
2. **docs/** - Create/update/remove human-readable documentation files for any changed features
3. **docs/README.md** - Timestamps, service listings, host roles, review dates, version numbers
4. **Code cleanup** - Stale firewall ports, dead config references (with user approval)

**CRITICAL: Always create human-readable docs in `docs/`.**
Code comments and inline documentation in `.nix` files are NOT a substitute for proper `docs/` entries. Even if a module is thoroughly self-documenting with comments, it MUST also have a corresponding `docs/` file that covers:
- What the feature/fix does and why it exists
- The root cause of the problem it solves
- Manual troubleshooting steps
- Related upstream issues/references

Never skip creating a `docs/` file with the argument that "the code is self-documenting" or "it's well-commented in the nix file". The `docs/` directory serves a different audience (humans browsing documentation) than code comments (developers reading source).

**NOTE on code fixes:** This skill primarily manages documentation. If code issues are discovered during audit (dead routes, stale ports), report them to the user and only fix with explicit approval.

For each file:
- Use Edit tool for surgical changes (not full rewrites)
- Update Last Modified dates to current date
- Change service status labels accurately (REMOVED vs DISABLED vs archived)
- Add missing services/features discovered in audit
- Remove references to deleted services

### Step 5: Verify Changes

```bash
# Review all changes
git diff --stat
git diff <file>  # for each modified file
```

Confirm no PII, secrets, or sensitive data in changes:
```bash
git diff --cached | grep -iE "password|secret|token|api.key|@gmail|phone|ssn" | head -20
```

### Step 6: Rebuild NixDocs (if docs changed)

If any files under `docs/` were modified, rebuild the misc host to update the NixDocs static site:

```bash
nixos-rebuild switch --flake .#misc --target-host misc.home.arpa
```

### Step 7: Commit and Push

Follow the git commit best practices from CLAUDE.md:
- Only `git add` untracked (new) files
- Use `git commit -a` for tracked files
- Split into atomic commits if changes span multiple concerns
- Comprehensive commit messages listing all significant changes
- Check for PII before pushing

## Key Audit Checks Reference

### Port Registry (CLAUDE.md)
- Every port number grep'd against `modules/services/*.nix` and `modules/desktop/**/*.nix`
- Firewall rules in `hosts/*/default.nix` match port registry
- Disabled ports are commented out in firewall
- Status labels: DISABLED (module exists but not imported), REMOVED (module deleted), archived (module exists for reference)

### System Facts (gathered from source, verified against docs/README.md)
- Kernel: `uname -r`
- Nixpkgs commit: `jq '.nodes.nixpkgs.locked.rev' /etc/nixos/flake.lock`
- Nixpkgs unstable commit: `jq '.nodes.nixpkgs-unstable.locked.rev' /etc/nixos/flake.lock`
- Secret count: `ls /etc/nixos/secrets/*.age | wc -l`
- NixOS version: check `flake.nix` branch reference
- Host count: count entries in `flake.nix` nixosConfigurations

### Service Status
- Check `hosts/*/default.nix` imports for what's actually enabled
- Check for `lib.mkIf false` patterns (disabled in code)
- Check for commented-out imports (disabled by exclusion)
- Check `archive/` directory for archived modules

### Timestamps
- CLAUDE.md: Last Modified
- docs/README.md: Last Updated, Last Security Review, Next Major Review

## Troubleshooting

### Agent finds too many false positives
Cause: Grepping for port numbers can match unrelated numbers
Solution: Cross-reference with context - check the surrounding nix attribute names, not just raw numbers

### Conflicting information between CLAUDE.md and docs/README.md
Cause: They serve different audiences (Claude AI vs humans) but should agree on facts
Solution: CLAUDE.md is the source of truth for port registry. docs/README.md is the source of truth for high-level architecture. Both must agree on service status.

### Rebuild fails after firewall changes
Cause: Commenting out a port may break a service that depends on it
Solution: Only comment out ports for truly disabled/removed services. Verify the service is not imported in any host before removing its port.


## Directive: update-skill
When the user says "update-skill", read [references/update-skill.md](references/update-skill.md) and follow those instructions.

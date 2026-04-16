---
name: system-audit
description: >
  Comprehensive audit of Arch Linux system state against the ~/arch declarative repo.
  Compares installed packages (pacman, AUR, nix, uv, cargo, bun, npm) against
  official.txt, aur.txt, archinstall JSON, and setup.sh declarations. Checks enabled
  systemd services, unmanaged config directories, manual binaries, timers, and
  flatpaks. Use when user says "audit my system", "system audit", "what's installed
  that isn't tracked", "check what's not declared", or "package drift". Reports
  actionable findings grouped by category with recommended actions.
user-invocable: true
disable-model-invocation: false
---

# System Audit

Audits live system state against `~/arch` declarations. Identifies undeclared packages, missing packages, service drift, unmanaged binaries, and other package manager state.

## Important

- Read `~/arch/CLAUDE.md` first for repo conventions and the System Audit section.
- Do NOT make changes unless the user asks. This skill is report-only by default.
- Run all independent data-gathering commands in parallel to minimize wall time.
- Distinguish between things that need action and things legitimately handled elsewhere (archinstall, setup.sh bootstrap, package dependencies).

## Instructions

### Step 1: Gather Data (parallel)

Run all of these in parallel using the Bash tool:

**Package lists from repo:**
- Read `~/arch/packages/official.txt`
- Read `~/arch/packages/aur.txt`
- Read `~/arch/install/user_configuration.json` (archinstall packages + gfx_driver profile)
- Read `~/arch/setup.sh` (for custom fork builds, nix packages, uv tools, cargo tools, bun globals)

**Live system state:**
- `pacman -Qqe | sort` (explicitly installed packages)
- `systemctl list-unit-files --state=enabled --no-pager --no-legend` (enabled system services)
- `systemctl --user list-unit-files --state=enabled --no-pager --no-legend` (enabled user services)
- `ls ~/.config/` (config directories)
- `ls /usr/local/bin/ ~/.local/bin/ ~/.cargo/bin/` (manual binaries)
- `flatpak list --app --columns=application` (flatpak apps)
- `nix profile list` (nix packages)
- `uv tool list` (uv tools)
- `bun pm ls -g` (bun globals)
- `npm list -g --depth=0` (npm globals)
- `cargo install --list` (cargo crates with binary names)
- `pip list --user` (user pip packages)
- `systemctl list-timers --all --no-pager --no-legend` (system timers)
- `systemctl --user list-timers --all --no-pager --no-legend` (user timers)
- `crontab -l` (cron jobs)

### Step 2: Build the Declared Package Set

Combine all sources into a single "declared" set:

1. **official.txt** - all entries
2. **aur.txt** - all entries
3. **archinstall JSON** - the `packages` array
4. **archinstall base** - always present: `base`, `linux`, `linux-firmware`, `efibootmgr`, `intel-ucode`, `sudo`
5. **archinstall KDE profile** - implicit packages from `gfx_driver` and desktop profile selections: `plasma-workspace`, `plasma-desktop`, `plasma-nm`, `plasma-pa`, `polkit-kde-agent`, `kwin`, `kscreen`, `breeze`, `xdg-desktop-portal-kde`
6. **archinstall GFX "All open-source"** - installs all open-source GPU drivers (intel, amd, nouveau, xorg). These show as explicitly installed but are from archinstall, not the repo.
7. **setup.sh custom builds** - `paru`, `lite-xl-custom`, `foot-custom` (plus their `-debug` variants)
8. **setup.sh other installs** - nix packages, uv tools, cargo tools, bun globals declared in setup.sh

### Step 3: Compare Packages

Run a precise diff:

```bash
# Packages installed but not declared
comm -23 <(pacman -Qqe | sort) <(sort official.txt aur.txt <(echo known_packages) | sort -u)

# Packages declared but not installed at all
comm -23 <(cat official.txt aur.txt | grep -v '^\s*$' | sort -u) <(pacman -Qq | sort)

# Packages declared but only installed as dependencies (not explicit)
# These are packages where pacman -S --needed skipped them because they were already deps
```

For packages in the lists but not showing in `pacman -Qqe`, check if they're installed as deps:
```bash
pacman -Qq <package>  # installed at all?
pacman -Qi <package> | grep "Install Reason"  # explicit or dep?
```

For undeclared packages, check:
```bash
pacman -Qi <package> | grep "Install Reason"  # explicit = user installed it
pactree -r <package>  # who depends on it?
pacman -Qi <package> | grep "Install Date"  # when was it installed?
```

### Step 4: Check Reverse Dependencies

For any package the user might want to remove, always check `pactree -r <package>` first. Some packages that look unnecessary are load-bearing dependencies (e.g., `wpa_supplicant` is required by `networkmanager`).

### Step 5: Compare Services

Build the "declared services" set from setup.sh:

- Config-free services in the `for svc in ...` loop
- Services enabled inline in their config sections (nftables, fail2ban, sshd, bluetooth, cups, docker, libvirtd, cockpit, ollama, xremap, ydotool)
- User services (xremap, ydotool, bw-serve, kde-timer-notifications, etc.)

Compare against `systemctl list-unit-files --state=enabled`. Categorize:
- **Declared but disabled** - setup.sh enables it but it's off (bug or manual override?)
- **Enabled but not declared** - needs to be added to setup.sh or is handled externally (nix installer, archinstall, systemd defaults)
- **System defaults** - `getty@.service`, `systemd-timesyncd`, `systemd-userdbd.socket`, `remote-fs.target`, etc. are expected

### Step 6: Check Other Package Managers

Compare declared state in setup.sh against live state for:
- **Nix**: `nix profile list` vs setup.sh nix package section
- **uv**: `uv tool list` vs setup.sh uv tools section
- **Cargo**: `cargo install --list` vs setup.sh cargo tools section
- **Bun**: `bun pm ls -g` vs setup.sh bun section
- **npm**: `npm list -g --depth=0`
- **pip**: `pip list --user` (should be empty - use venvs)
- **Flatpak**: `flatpak list --app`

### Step 7: Check Binaries

Scan for unmanaged binaries:
- `/usr/local/bin/` - should only have system-level tools (e.g., determinate-nixd from Nix)
- `~/.local/bin/` - compare against setup.sh's shell script symlink loop and bin/ script symlinks
- `~/.cargo/bin/` - compare against cargo install --list and setup.sh declarations

For unknown binaries, use `file` to identify type and `strings <binary> | grep -i usage` to identify purpose.

### Step 8: Check Config Directories

List `~/.config/` and compare against configs deployed by setup.sh (both `link_config` and `copy_config` calls). Most unmanaged directories are app-generated data (browser profiles, app settings) that don't need tracking. Flag directories that look like they contain reproducible config that should be in the repo.

### Step 9: Report

Present findings in these categories, using markdown tables:

1. **Packages installed but not declared** - subdivide into:
   - Should be added to official.txt (intentional installs)
   - Should be added to aur.txt
   - Archinstall GFX/profile packages (legitimate, document only)
   - Build deps or one-offs (candidates for removal or marking as deps)
2. **Packages declared but not installed** - distinguish between completely missing and installed-as-dep-only
3. **Service discrepancies** - declared-but-disabled, enabled-but-not-declared
4. **Manual binaries** - unmanaged executables
5. **Other package managers** - undeclared installs
6. **Timers and cron jobs** - anything not from standard system packages

End with a **Recommended actions** list ordered by priority (bugs and broken state first, then declarations, then cleanup).

## Troubleshooting

### pacman -Qqe shows packages that were installed via pacman -S --needed
`pacman -S --needed` does NOT change install reason if the package is already installed as a dependency. Packages pulled in as deps before setup.sh ran will stay as deps. Fix with `sudo pacman -D --asexplicit <package>`.

### Archinstall "All open-source" GFX driver packages
The `gfx_driver: "All open-source"` profile installs ALL open-source GPU drivers (Intel, AMD, Nouveau) plus Xorg. These show as explicitly installed but are expected. The user's machine has AMD + Intel (no NVIDIA), so nouveau packages are unnecessary but harmless.

### Service shows disabled but setup.sh has enable logic
This means either setup.sh hasn't been run since the service was disabled, or it was manually disabled. The setup.sh logic is correct - next run will re-enable it. Only flag as a bug if the enable logic is missing from setup.sh.

### cups bug pattern
If setup.sh deploys config for a service but the package isn't in official.txt or aur.txt, that's a bug. On fresh install the config deployment will fail because the package won't be installed yet. Always verify that packages referenced in setup.sh config sections are declared in the package lists.

## Directive: update-skill
When the user says "update-skill", read [references/update-skill.md](references/update-skill.md) and follow those instructions.

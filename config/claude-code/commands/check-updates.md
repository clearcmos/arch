---
description: Check for available pacman and AUR updates and assess risk
allowed-tools: Bash(checkupdates:*), Bash(paru -Qua:*), Bash(ls ~/arch/upgrades:*), Agent, Write
---

## Instructions

1. Run `checkupdates` and `paru -Qua` in parallel to get available pacman and AUR updates
2. Do NOT run the actual updates - this is read-only

## Phase 1: Risk Summary

Provide a short summary with counts (pacman and AUR), then a risk assessment covering:

- **Kernel**: note version change, whether it requires reboot
- **GPU/Mesa/ROCm**: relevant to AMD RX 6800 XT and ollama-rocm
- **Desktop (KDE Plasma/KWin/KF6)**: note if major or minor release
- **Security-relevant**: openssl, openssh, cryptsetup, libcbor (FIDO2), python-cryptography, etc.
- **Notable version jumps**: major version bumps in libraries or tools that could break things
- **Bulk noise**: identify rebuild batches (haskell, qemu, vlc, etc.) that are just pkgrel bumps with no real change
- **AUR highlights**: anything notable in the AUR list

End Phase 1 with a one-line bottom-line verdict: low/medium/high risk, and whether it is safe to run.

Keep the output concise. Do not list every package - group and summarize.

## Phase 1.5: Arch Linux News

Fetch `https://archlinux.org/news/` and check for any recent posts that require manual intervention before or during the upgrade. Look for posts from the last 30 days that mention:

- Required manual steps before upgrading (keyring updates, package replacements, config migrations)
- Known incompatibilities or breakage with packages in the current update list
- Pacman or filesystem changes that need action

If any relevant news posts are found, summarize them prominently before Phase 2 output and flag any required pre-upgrade steps. If nothing relevant, note "No manual interventions required per archlinux.org/news."

Include any relevant findings in the Warnings section of the Phase 3 report under a "### Arch news - manual intervention" heading (only if applicable).

## Phase 2: Upstream Changelogs

After Phase 1, fetch upstream changelogs for all important packages. Skip bulk rebuild noise (haskell, qemu, vlc pkgrel bumps, etc.) and routine Electron app updates (spotify, discord, slack). Focus on packages where the changelog content could reveal security fixes, breaking changes, or regressions.

### Which packages to check

Select packages from the update list that fall into any of these categories:

1. **Kernel** - linux
2. **Security** - openssl, openssh, cryptsetup, libcbor, libfido2, python-cryptography, libsodium, wolfssl, leancrypto, gnupg, webkit2gtk, glib2
3. **GPU/compute** - mesa, vulkan-radeon, ROCm stack (any rocm-/roc/hip/hsa- package), ollama, ollama-rocm
4. **Desktop** - plasma-workspace (covers Plasma point releases), kwin, pipewire, xorg-xwayland, wayland-protocols
5. **Major version jumps** - any package where the major version number changes (e.g. 5.x -> 6.x)
6. **Infrastructure** - docker, libvirt, python (the interpreter), iptables/nftables, systemd, flatpak, cockpit
7. **Input/display** - xremap*, libinput, xorg-server
8. **User-facing tools with breaking change potential** - fzf, ruff, uv, deno, go, rclone, 1password-cli

### How to fetch

Spawn 4-6 parallel Agent workers (subagent_type: general-purpose), each handling a batch of packages. Each agent's prompt must:

- List the specific packages and their old -> new versions
- Provide the known upstream URL for each (see URL patterns below)
- Ask for 2-4 bullet points per package, focusing on: CVEs/security fixes, breaking changes, deprecations, and changes relevant to AMD GPU / Arch Linux / KDE Wayland
- Request the output format: `**package version**` followed by bullets

### Upstream URL patterns

Use these as starting points. Agents should fall back to WebSearch if a URL 404s.

| Package | Changelog URL |
|---------|--------------|
| linux | `https://cdn.kernel.org/pub/linux/kernel/v{major}.x/ChangeLog-{version}` |
| openssl | `https://github.com/openssl/openssl/releases` |
| openssh | `https://www.openssh.com/txt/release-{major}.{minor}` |
| cryptsetup | `https://gitlab.com/cryptsetup/cryptsetup/-/tags` |
| libcbor | `https://github.com/PJK/libcbor/releases` |
| libfido2 | `https://github.com/Yubico/libfido2/releases` |
| python-cryptography | `https://github.com/pyca/cryptography/blob/main/CHANGELOG.rst` |
| libsodium | `https://github.com/jedisct1/libsodium/releases` |
| mesa | `https://docs.mesa3d.org/relnotes/{version}.html` |
| ROCm | `https://github.com/ROCm/ROCm/releases` |
| ollama | `https://github.com/ollama/ollama/releases` |
| plasma-workspace | `https://kde.org/announcements/plasma/6/{version}/` |
| kwin | same as plasma-workspace (released together) |
| pipewire | `https://gitlab.freedesktop.org/pipewire/pipewire/-/tags` |
| xorg-xwayland | `https://gitlab.freedesktop.org/xorg/xserver/-/tags` |
| wayland-protocols | `https://gitlab.freedesktop.org/wayland/wayland-protocols/-/tags` |
| docker | `https://github.com/moby/moby/releases` |
| libvirt | `https://libvirt.org/news.html` |
| python | `https://www.python.org/downloads/` |
| chromium | `https://chromereleases.googleblog.com/` |
| firefox | `https://www.mozilla.org/en-US/firefox/{version}/releasenotes/` |
| glib2 | `https://gitlab.gnome.org/GNOME/glib/-/tags` |
| gtk4 | `https://gitlab.gnome.org/GNOME/gtk/-/tags` |
| harfbuzz | `https://github.com/harfbuzz/harfbuzz/releases` |
| iptables | `https://git.netfilter.org/iptables/` |
| cockpit | `https://github.com/cockpit-project/cockpit/releases` |
| fzf | `https://github.com/junegunn/fzf/releases` |
| ruff | `https://github.com/astral-sh/ruff/releases` |
| uv | `https://github.com/astral-sh/uv/releases` |
| deno | `https://github.com/denoland/deno/releases` |
| go | `https://go.dev/doc/devel/release` |
| rclone | `https://github.com/rclone/rclone/releases` |
| 1password-cli | `https://app-updates.agilebits.com/product_history/CLI2` |
| xremap | `https://github.com/xremap/xremap/releases` |
| systemd | `https://github.com/systemd/systemd/releases` |
| flatpak | `https://github.com/flatpak/flatpak/releases` |
| giflib | `https://sourceforge.net/projects/giflib/files/` |
| iproute2 | `https://git.kernel.org/pub/scm/network/iproute2/iproute2.git/log/` |
| simdjson | `https://github.com/simdjson/simdjson/releases` |
| libinput | `https://gitlab.freedesktop.org/libinput/libinput/-/tags` |
| webkit2gtk | `https://webkitgtk.org/releases/` |

For packages not listed, search `https://github.com/{org}/{package}/releases` or use WebSearch as a fallback.

When a package jumps multiple versions (e.g. ollama 0.18 -> 0.20), scan all intermediate releases and summarize the highlights across the full range.

### Phase 2 output format

After all agents return, compile a single **Upstream Changelogs** section organized by category (Security, GPU/ROCm, Desktop, Major Version Jumps, Infrastructure, Tools). For each package, show:

```
**package version**
- bullet 1
- bullet 2
```

Then update the bottom-line verdict from Phase 1 if the changelog findings change the risk assessment (e.g. if CVEs are found that were not obvious from version numbers alone).

## Phase 3: Upgrade Report

After completing Phases 1 and 2, write a datestamped report to `~/arch/upgrades/YYYY-MM-DD.md` (using today's date). This file serves as a post-upgrade trace the user can reference if something breaks after rebooting.

The report must include these sections in order:

### Structure

```markdown
# Upgrade Report - YYYY-MM-DD

Pacman: N packages | AUR: N packages

## Warnings

### Security - CVEs patched in this upgrade
List each package with its CVE IDs and one-line descriptions.

### Breaking changes
List ABI breaks, API renames, changed defaults, and anything requiring user action.

### Requires reboot
Kernel version change and notable fixes in the new kernel.

## What this upgrades
Group all packages by category. For each, show old -> new version.
Categories: Kernel, GPU/Mesa/ROCm, Desktop, Audio, Display/Wayland,
Security stack, Infrastructure, Browsers, Core libraries, LLVM toolchain,
Dev tools, Applications, Bulk rebuilds, AUR.
Only list bulk rebuilds as a count with a note (e.g. "~160 haskell-* packages, pandoc rebuild").

## Post-upgrade checklist
Generate a markdown checklist of things to verify after reboot, based on what changed.
Always include reboot if kernel updated. Include items for:
- ROCm/ollama if GPU stack changed
- FIDO2/security keys if libcbor/libfido2 changed
- Desktop session if Plasma/KWin changed
- Audio if pipewire changed
- Input remapping if xremap changed
- Any other package with breaking changes

## Verdict
One-line risk assessment carried forward from Phase 2.
```

If a report for today's date already exists, overwrite it (the user may re-run the command after partial upgrades).

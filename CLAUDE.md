# ~/arch

Idempotent Arch Linux post-install setup script and config files for a personal workstation. The single entry point is `./setup.sh`, which installs packages, enables services, and deploys config files.

## Architecture

- `setup.sh` - Main bash script. Idempotent: uses `--needed` flags, `command -v` guards, and `systemctl is-enabled` checks so re-runs are safe.
- `packages/official.txt` - Pacman packages, one per line, alphabetically sorted. This is the single source of truth for all official packages.
- `packages/aur.txt` - AUR packages (installed via paru), same format.
- `services.txt` - Systemd services to enable. Lines prefixed with `user:` are user-level services.
- `config/` - Config files deployed to `~/.config/` or `/etc/`. KDE configs are copied (KConfig's atomic writes break symlinks). Non-KDE user configs are symlinked. System configs under `/etc/` are copied (require root ownership).
- `install/` - archinstall config and installer script. `user_configuration.json` has system settings (disk, locale) and a minimal boot-only package set (just enough for KDE + network + terminal). All other packages live in `packages/official.txt` and are installed by `setup.sh`. `install.sh` is the entry point -- it prompts for passwords, hashes them, writes a temporary credentials file, and runs archinstall. The disk `device` field uses `/dev/disk/by-id/` (serial-based) instead of `/dev/nvmeXnY` because NVMe device numbering is not stable across reboots. No passwords or secrets are stored in the repo.

## Fresh Install from Arch ISO

From the Arch ISO (booted as root):

```bash
bash <(curl -sL clearcmos.com/go)
```

This fetches `install/bootstrap.sh` (via Cloudflare redirect), which downloads the install config and runs `install.sh`. The script prompts for root and user passwords, then runs archinstall. After install, custom commands clone the repo to `~/arch`, deploy greetd/tuigreet config, sysctl quiet console, and set up the first-login autostart.

After reboot, log in via tuigreet — a konsole window opens automatically and runs `setup.sh`. On success it offers to reboot; on failure it offers to open the log.

## Setup Flow Order

1. System update (`pacman -Syu`)
2. Official packages (pacman)
3. AUR helper (paru) if missing
4. Rust via rustup if missing (removes distro `rust` package if present)
5. AUR packages (paru)
6. Nix via Determinate Systems installer if missing
7. Claude Code if missing
8. Enable and start systemd services (including `pcscd` for YubiKey)
9. AMD GPU kernel params
10. Font rendering (system-level fontconfig in `/etc/fonts/conf.d/`)
11. KDE settings (lock screen, hot corners, dark theme)
12. Mount points (data disk + NAS, explicit mount for mid-script access)
13. SSH key restore from NAS (age-encrypted, YubiKey decryption — prompts for YubiKey)
14. Git/GitHub config (interactive `gh auth login` with YubiKey passkey)
15. SSH server config
16. Deploy config files (copy KDE configs including monitor layout, symlink the rest)
17. Bluetooth pairing (background scan with polling)

## Desktop Environment

KDE Plasma 6 on Wayland. Stack: KDE Plasma + KWin + greetd/tuigreet (login) + Thunar/Dolphin (file managers) + BreezeDark (theme).

## SSH Key Management

SSH keys are encrypted with `age` + `age-plugin-yubikey` and stored on the NAS at `/mnt/syno/backups/ssh/cmos-arch/`. The YubiKey identity file lives in `config/age/yubikey-identity.txt` (safe to commit - just a slot reference). Decryption requires the physical YubiKey (PIN + touch). On fresh install, the script restores the key automatically.

## Security Model

Single-user personal workstation on a home LAN (192.168.1.0/24). The router only forwards ports 80/443 to misc.home.arpa (not this machine). WAN access to this machine's services (Cockpit) is proxied through Traefik + Keycloak on misc.

### Threat Assumptions

- **Lateral movement from LAN**: A compromised device on the network could reach this machine. Mitigated by nftables (default-deny inbound, LAN-only rules for SSH/Cockpit), fail2ban, and key-only SSH.
- **Supply chain (packages)**: AUR packages could contain malicious code. Mitigated by PKGBUILD auditing, pacman pre-transaction hooks, and archival of all PKGBUILDs for post-audit.
- **Secret leakage**: Credentials could be committed to git. Mitigated by YubiKey-encrypted SSH keys, 1Password CLI runtime injection, trufflehog scanning, and git-filter-repo for history rewriting.
- **Config drift**: Deployed configs silently diverging from the repo could mask tampering. Mitigated by `tools/check-drift.sh` on all copied configs.

### Principles for Changes

1. **Flag security side-effects proactively.** If a change opens a port, weakens auth, adds a privileged service, or touches secrets handling, say so before making it - even if the user didn't ask about security.
2. **Least privilege by default.** New services should run unprivileged. New mounts should have restrictive flags. New firewall rules should be LAN-scoped unless there's a reason not to.
3. **Verify before weakening.** Before removing or loosening a security control, check why it exists by reading the relevant config. It may be load-bearing for something non-obvious (e.g. Brave requires unprivileged user namespaces for sandboxing).
4. **Secrets never in repo.** No API keys, passwords, tokens, or private keys. If a config needs a secret at runtime, use 1Password CLI (`op run`) or age-encrypted files with YubiKey.

## Maintenance

- When adding packages, verify online whether they belong in `official.txt` (pacman) or `aur.txt` (paru). Packages move between repos over time.
- When adding new config files, add them to `setup.sh` using `copy_config` for KDE files or `link_config` for everything else.
- Do not update CLAUDE.md or setup.sh when making config/system changes until the changes are tested and confirmed working by the user.

## check-drift (tools/check-drift.sh)

Detects when deployed config copies have diverged from the repo. Only **copied** configs need drift checking - symlinked configs point directly to the repo and cannot drift.

- When adding a new `copy_config` deployment or `sudo cp` to setup.sh, add a matching `check` line to `tools/check-drift.sh`.
- Do NOT add entries for `link_config` deployments (symlinks don't drift).
- Do NOT add entries for configs that are routinely modified by their application at runtime (e.g. Lutris game configs, CurseForge). Drift checking those would just produce noise.
- Configs that are only read from the repo at runtime (e.g. `config/age/yubikey-identity.txt`) or only used by the installer (e.g. `config/autostart/first-login.desktop`) are not deployed by setup.sh and do not need drift entries.
- Scripts that are executed by setup.sh rather than deployed (e.g. `config/kwin/setup-kwin-scripts.sh`) also do not need drift entries.

## Key Conventions

- All idempotency must be preserved when modifying `setup.sh` - never add operations that fail or duplicate on re-run.
- Both `official.txt` and `aur.txt` are flat alphabetical lists with no comments or categories.
- **Every config file must live in this repo and be deployed to its target location.** Never create or edit config files directly in `~/.config/` or elsewhere - always add them under `config/` in this repo and deploy via `setup.sh`. The repo is the single source of truth for all configuration. KDE configs are copied (not symlinked) because KConfig's QSaveFile atomic writes break symlinks. System configs under `/etc/` are also copied (require root ownership). System-level fontconfig uses symlinks from `/usr/share/fontconfig/conf.avail/` to `/etc/fonts/conf.d/`.
- The script targets a single machine with AMD RX 6800 XT GPU and Intel i7-13700K.

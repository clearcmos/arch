# ~/git/mine/arch

Idempotent Arch Linux post-install setup script and config files for a personal workstation. The single entry point is `./setup.sh`, which installs packages, enables services, and deploys config files.

## Architecture

- `setup.sh` - Main bash script. Idempotent: uses `--needed` flags, `command -v` guards, and `systemctl is-enabled` checks so re-runs are safe.
- `packages/official.txt` - Pacman packages, one per line. Comments (`#`) and blank lines are stripped.
- `packages/aur.txt` - AUR packages (installed via paru), same format.
- `services.txt` - Systemd services to enable. Lines prefixed with `user:` are user-level services.
- `config/` - Config files deployed to `~/.config/` or `/etc/`. KDE configs are copied (KConfig's atomic writes break symlinks). Non-KDE user configs are symlinked. System configs under `/etc/` are copied (require root ownership).
- `install/` - archinstall config and installer script. `user_configuration.json` has system settings (disk, packages, locale). `install.sh` is the entry point — it prompts for passwords, hashes them, writes a temporary credentials file, and runs archinstall. The disk `device` field uses `/dev/disk/by-id/` (serial-based) instead of `/dev/nvmeXnY` because NVMe device numbering is not stable across reboots. No passwords or secrets are stored in the repo.

## Fresh Install from Arch ISO

From the Arch ISO (booted as root):

```bash
bash <(curl -sL clearcmos.com/go)
```

This fetches `install/bootstrap.sh` (via Cloudflare redirect), which downloads the install config and runs `install.sh`. The script prompts for root and user passwords, then runs archinstall. After install, the repo is automatically cloned to `~/arch` via archinstall's custom commands.

After reboot, run `~/arch/setup.sh` to complete post-install setup.

## Setup Flow Order

1. System update (`pacman -Syu`)
2. Official packages (pacman)
3. AUR helper (paru) if missing
4. AUR packages (paru)
5. Rust via rustup if missing
6. Nix via Determinate Systems installer if missing
7. Claude Code if missing
8. Enable systemd services (including `pcscd` for YubiKey)
9. AMD GPU kernel params
10. Font rendering (system-level fontconfig in `/etc/fonts/conf.d/`)
11. KDE dark theme (BreezeDark)
12. Mount points (data disk + NAS)
13. SSH key restore from NAS (age-encrypted, YubiKey decryption)
14. Git/GitHub config
15. SSH server config
16. Deploy config files (copy KDE configs, symlink the rest)
17. Bluetooth pairing

## Desktop Environment

KDE Plasma 6 on Wayland. Stack: KDE Plasma + KWin + greetd/tuigreet (login) + Thunar/Dolphin (file managers) + BreezeDark (theme).

## SSH Key Management

SSH keys are encrypted with `age` + `age-plugin-yubikey` and stored on the NAS at `/mnt/syno/backups/ssh/cmos-arch/`. The YubiKey identity file lives in `config/age/yubikey-identity.txt` (safe to commit - just a slot reference). Decryption requires the physical YubiKey (PIN + touch). On fresh install, the script restores the key automatically.

## Maintenance

- When adding packages, verify online whether they belong in `official.txt` (pacman) or `aur.txt` (paru). Packages move between repos over time.
- When adding new config files, add them to `setup.sh` using `copy_config` for KDE files or `link_config` for everything else.
- Do not update CLAUDE.md or setup.sh when making config/system changes until the changes are tested and confirmed working by the user.

## Key Conventions

- All idempotency must be preserved when modifying `setup.sh` - never add operations that fail or duplicate on re-run.
- `official.txt` uses comments for category grouping; maintain this when adding packages. `aur.txt` is a flat alphabetical list with no comments.
- **Every config file must live in this repo and be deployed to its target location.** Never create or edit config files directly in `~/.config/` or elsewhere - always add them under `config/` in this repo and deploy via `setup.sh`. The repo is the single source of truth for all configuration. KDE configs are copied (not symlinked) because KConfig's QSaveFile atomic writes break symlinks. System configs under `/etc/` are also copied (require root ownership). System-level fontconfig uses symlinks from `/usr/share/fontconfig/conf.avail/` to `/etc/fonts/conf.d/`.
- The script targets a single machine with AMD RX 6800 XT GPU and Intel i7-13700K.

# ~/git/mine/arch

Idempotent Arch Linux post-install setup script and config files for a personal workstation. The single entry point is `./setup.sh`, which installs packages, enables services, and symlinks config files.

## Architecture

- `setup.sh` - Main bash script. Idempotent: uses `--needed` flags, `command -v` guards, and `systemctl is-enabled` checks so re-runs are safe.
- `packages/official.txt` - Pacman packages, one per line. Comments (`#`) and blank lines are stripped.
- `packages/aur.txt` - AUR packages (installed via paru), same format.
- `services.txt` - Systemd services to enable. Lines prefixed with `user:` are user-level services.
- `config/` - Config files that get symlinked into `~/.config/` (or copied to `/etc/` for system configs like greetd). These are the live configs - editing them here or at their symlink destination is equivalent.

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
16. Symlink config files
17. Bluetooth pairing

## Desktop Environment

KDE Plasma 6 on Wayland. Stack: KDE Plasma + KWin + SDDM (login) + Thunar/Dolphin (file managers) + BreezeDark (theme).

## SSH Key Management

SSH keys are encrypted with `age` + `age-plugin-yubikey` and stored on the NAS at `/mnt/syno/backups/ssh/cmos-arch/`. The YubiKey identity file lives in `config/age/yubikey-identity.txt` (safe to commit - just a slot reference). Decryption requires the physical YubiKey (PIN + touch). On fresh install, the script restores the key automatically.

## Maintenance

- When adding packages, verify online whether they belong in `official.txt` (pacman) or `aur.txt` (paru). Packages move between repos over time.
- When adding new config files or symlinks, add them to the `link_config` section in `setup.sh`.
- Do not update CLAUDE.md or setup.sh when making config/system changes until the changes are tested and confirmed working by the user.

## Key Conventions

- All idempotency must be preserved when modifying `setup.sh` - never add operations that fail or duplicate on re-run.
- Package lists use comments for category grouping; maintain this when adding packages.
- **Every config file must live in this repo and be symlinked to its target location.** Never create or edit config files directly in `~/.config/` or elsewhere - always add them under `config/` in this repo and symlink via `setup.sh`. The repo is the single source of truth for all configuration. Exception: system configs under `/etc/` are copied (require root ownership), and system-level fontconfig uses symlinks from `/usr/share/fontconfig/conf.avail/` to `/etc/fonts/conf.d/`.
- The script targets a single machine with AMD RX 6800 XT GPU and Intel i7-13700K.

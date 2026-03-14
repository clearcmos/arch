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
7. Claude Code via npm if missing
8. Enable systemd services
9. Symlink config files

## Desktop Environment

Hyprland (Wayland) configured in **all-floating mode** (no tiling) for a KDE-like UX. Stack: Hyprland + hyprbars (title bars) + hyprfloat (window snapping) + hyprswitch (alt-tab) + Waybar (bottom taskbar) + Rofi (app launcher) + Mako (notifications) + Thunar (file manager) + Catppuccin Mocha (GTK theme) + greetd/tuigreet (login).

## Maintenance

- Always keep `README.md` up to date when making changes - remove anything that no longer applies and add new sections as needed.
- When adding packages, verify online whether they belong in `official.txt` (pacman) or `aur.txt` (paru). Packages move between repos over time.
- When adding a new operation category to `setup.sh`, add matching validation in the `--dry-run` block. The dry run must stay in sync with the real run.
- When adding new config files or symlinks, add them to both the `link_config` section in `setup.sh` and the `config_files` array in the dry-run block.
- Do not update README.md, CLAUDE.md, setup.sh, or dry-run validation when making config/system changes until the changes are tested and confirmed working by the user.
- Run `./setup.sh --dry-run` after any change to package lists or setup logic to catch problems early.

## Key Conventions

- All idempotency must be preserved when modifying `setup.sh` - never add operations that fail or duplicate on re-run.
- Package lists use comments for category grouping; maintain this when adding packages.
- User configs are **symlinked** (not copied) so the repo stays the source of truth. Exception: `/etc/greetd/config.toml` is copied (requires root ownership).
- The script targets a single machine with AMD RX 6800 XT GPU and Intel i7-13700K.

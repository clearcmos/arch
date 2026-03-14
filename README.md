# Arch Setup

Idempotent post-install script for my Arch Linux workstation. Run once on a fresh install, or re-run anytime to sync changes.

## Usage

```bash
sudo pacman -S git
git clone <repo-url> ~/git/mine/arch
cd ~/git/mine/arch
./setup.sh
# reboot
```

Re-running `./setup.sh` is always safe - it skips anything already installed/enabled.

Use `./setup.sh --dry-run` to validate everything without making changes.

## What It Does

1. System update
2. Installs packages from `packages/official.txt` (pacman) and `packages/aur.txt` (paru)
3. Installs standalone tools (Rust via rustup, Nix, Claude Code, hyprfloat) if not present
4. Sets up Hyprland plugins (hyprbars) via hyprpm
5. Enables systemd services listed in `services.txt`
6. Symlinks config files from `config/` into `~/.config/`, `~/.claude/`, and `~/.local/share/`

## Config Files

Files in `config/` are symlinked to their expected locations. Editing either path changes the same file - changes are already in the repo, ready to commit.

## Keybinds

See `config/hyprland/hyprland.conf` for the full list. Highlights:

| Key | Action |
|---|---|
| `Super+Return` | Terminal (Ghostty) |
| `Super+Space` | App launcher (Rofi) |
| `Super+E` | File manager (Thunar) |
| `Super+Q` | Close window |
| `Super+Up` | Maximize |
| `Super+Left` | Snap left (repeat to cross monitors) |
| `Super+Right` | Snap right (repeat to cross monitors) |
| `Alt+Tab` | Window switcher (hyprswitch) |
| `Print` | Screenshot (area) |
| `Shift+Print` | Screenshot (full) |

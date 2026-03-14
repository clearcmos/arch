# Arch Setup

Idempotent post-install script for my Arch Linux workstation. Run once on a fresh install, or re-run anytime to sync changes.

## Usage

```bash
sudo pacman -S git
git clone <repo-url> ~/git/arch
cd ~/git/arch
./setup.sh
# reboot
```

Re-running `./setup.sh` is always safe -it skips anything already installed/enabled.

## What It Does

1. System update
2. Installs packages from `packages/official.txt` (pacman) and `packages/aur.txt` (paru)
3. Installs standalone tools (Rust via rustup, Nix, Claude Code) if not present
4. Enables systemd services listed in `services.txt`
5. Symlinks config files from `config/` into `~/.config/`

## Adding Packages

Edit `packages/official.txt` or `packages/aur.txt`, one package per line. Re-run `./setup.sh`.

## Config Files

Files in `config/` are symlinked to their expected locations (e.g. `config/hyprland/hyprland.conf` -> `~/.config/hypr/hyprland.conf`). Editing either path changes the same file -changes are already in the repo, ready to commit.

## Keybinds

See `config/hyprland/hyprland.conf` for the full list. Highlights:

| Key | Action |
|---|---|
| `Super+Return` | Terminal |
| `Super+Space` | App launcher |
| `Super+E` | File manager |
| `Super+Q` | Close window |
| `Super+F` | Fullscreen |
| `Alt+Tab` | Cycle windows |
| `Print` | Screenshot (area) |
| `Shift+Print` | Screenshot (full) |

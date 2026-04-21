# Per-user Tailscale profile switching

## Overview

Tailscale stores multiple named profiles (accounts) in its daemon state and lets you flip between them with `tailscale switch <name>`. The daemon has exactly one active profile at any moment — it's a system-wide setting, not per-user — but switching is instant, no re-auth, no browser.

This doc covers how to automatically switch profiles based on which KDE user is logged in:

- `nicholas` (personal KDE user) → personal tailnet
- `nicholas.bedros` (work KDE user) → work tailnet

Fast-user-switching between the two sessions flips the active tailnet. Last-active session wins. That's the intended behaviour.

## One-time profile setup

The named profiles have to exist before switching works. Establish each profile by logging in once with the corresponding account.

As `nicholas`:

```bash
sudo tailscale login --profile-name personal
```

Follow the browser auth flow, land back on the terminal. Verify:

```bash
tailscale status
# Should show personal tailnet
tailscale switch --list
# Should list a profile named 'personal'
```

Switch user (KDE fast-user-switching or logout/login) to `nicholas.bedros`:

```bash
sudo tailscale login --profile-name work
```

Authenticate with the work account. Verify with the same two commands.

After this, both profiles live in `/var/lib/tailscale/`. You never need to re-run `tailscale login` unless a profile is revoked.

## Automatic switching on KDE login

Three pieces:

### 1. A tiny shell script

`/usr/local/bin/tailscale-profile-sync`:

```bash
#!/usr/bin/env bash
set -u

case "$USER" in
  nicholas)        profile=personal ;;
  nicholas.bedros) profile=work ;;
  *)               exit 0 ;;
esac

if ! out=$(sudo -n tailscale switch "$profile" 2>&1); then
  logger -t tailscale-profile-sync "failed to switch to $profile: $out"
  exit 1
fi

logger -t tailscale-profile-sync "switched to $profile"
```

Deploy (as `nicholas` with sudo):

```bash
sudo install -m 0755 tailscale-profile-sync /usr/local/bin/
```

### 2. A sudoers rule

`/etc/sudoers.d/tailscale-switch`:

```
# Allow per-user tailscale profile switching without a password.
# `tailscale switch` only toggles which saved profile is active; it cannot
# add/modify profiles or expose new network surface.
nicholas        ALL=(root) NOPASSWD: /usr/bin/tailscale switch personal
nicholas.bedros ALL=(root) NOPASSWD: /usr/bin/tailscale switch work
```

Deploy:

```bash
sudo install -m 0440 -o root -g root tailscale-switch /etc/sudoers.d/
```

Verify the file parses cleanly:

```bash
sudo visudo -c -f /etc/sudoers.d/tailscale-switch
```

### 3. A KDE autostart entry per user

`~/.config/autostart/tailscale-profile.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Tailscale profile sync
Comment=Switch the tailscale daemon to the profile matching the active KDE user
Exec=/usr/local/bin/tailscale-profile-sync
OnlyShowIn=KDE;
X-KDE-autostart-phase=2
```

Drop a copy (or symlink) in each user's `~/.config/autostart/`:

```bash
# As nicholas
mkdir -p ~/.config/autostart
cp tailscale-profile.desktop ~/.config/autostart/

# As nicholas.bedros
mkdir -p ~/.config/autostart
cp tailscale-profile.desktop ~/.config/autostart/
```

Next KDE login triggers the script automatically.

## Verifying it works

Log in as `nicholas`, open a terminal:

```bash
journalctl -t tailscale-profile-sync -n 5
tailscale status | head -5   # should show the personal tailnet
```

Fast-user-switch to `nicholas.bedros`:

```bash
journalctl -t tailscale-profile-sync -n 5
tailscale status | head -5   # should show the work tailnet
```

## Making it declarative

To fold this into `setup.sh`:

1. Commit the script to `~/arch/bin/tailscale-profile-sync`
2. Commit the sudoers rule to `~/arch/config/sudoers.d/tailscale-switch`
3. Commit the autostart entry to `~/arch/config/autostart/tailscale-profile.desktop`
4. Add deployment lines to `setup.sh`:
   ```bash
   sudo install -m 0755 "$SCRIPT_DIR/bin/tailscale-profile-sync" /usr/local/bin/
   sudo install -m 0440 -o root -g root "$SCRIPT_DIR/config/sudoers.d/tailscale-switch" /etc/sudoers.d/
   link_config "$SCRIPT_DIR/config/autostart/tailscale-profile.desktop" "$HOME/.config/autostart/tailscale-profile.desktop"
   ```
5. Add the autostart link to `work-profile/setup.sh` so `nicholas.bedros` gets it on their first run.

The one-time `tailscale login --profile-name <name>` steps stay manual because they require a browser auth round trip.

## Caveats

- **System-wide, not per-session.** If both KDE sessions are open simultaneously (fast-user-switching without logout), the last session to trigger the autostart wins. Services reachable only on one tailnet go offline in the other session until you switch back.
- **Sudoers rule is narrowly scoped.** Each user can only switch to their designated profile, not the other user's. Prevents `nicholas` from accidentally flipping to the work tailnet or vice versa.
- **Browser auth required the first time per profile.** After that, profiles persist across reboots.
- **Removing a device from a tailnet invalidates its profile.** If the tailnet admin revokes the device, `tailscale switch <profile>` will succeed but `tailscale status` will show disconnected. Re-run `sudo tailscale login --profile-name <profile>` to re-auth.

# Restic Backup

## Overview

Restic backs up files as deduplicated, encrypted snapshots. Each backup is a point-in-time snapshot - nothing is overwritten or deleted. Restoring a single file from last Tuesday is as easy as restoring the whole thing.

## Concepts

- **Repository** - where restic stores encrypted backup data. Can be a local path, SFTP, S3, rclone remote, etc.
- **Snapshot** - a single backup run. Each snapshot records the full file tree, but only new/changed chunks are actually stored.
- **Password** - every repo is encrypted. You pick a password at init time and need it for every operation.

## Setup

### Initialize a repository

Pick a location and init:

```bash
# Local path (e.g. NAS mount)
restic init -r /mnt/syno/backups/restic

# SFTP
restic init -r sftp:user@host:/backups/restic

# rclone remote (any rclone-supported backend)
restic init -r rclone:remote:path/to/repo
```

You'll be prompted for a password. Store it somewhere safe (1Password, etc).

### Environment variables

On this machine, `RESTIC_REPOSITORY` and `RESTIC_PASSWORD_COMMAND` are set declaratively via `config/environment.d/40-restic.conf`, deployed by `setup.sh` to `~/.config/environment.d/40-restic.conf`. systemd user sessions load these at login, so restic commands work with no manual exports.

Password is pulled at runtime from 1Password: `op read op://backups/RESTIC_PW_CMOS_ARCH/password`. The item must exist in the `backups` vault before `setup.sh` can initialize the repo; setup.sh will skip the init step with a clear message otherwise.

For other hosts or one-off use, export the vars manually:

```bash
export RESTIC_REPOSITORY=/path/to/repo
export RESTIC_PASSWORD_COMMAND="op read op://<vault>/<item>/password"
# or use a password file:
export RESTIC_PASSWORD_FILE=/path/to/password-file
```

## Daily use

### Back up

Using the config files in `config/restic/` (env vars come from `environment.d/40-restic.conf`):

```bash
restic backup \
  --files-from ~/arch/config/restic/includes.txt \
  --exclude-file ~/arch/config/restic/excludes.txt
```

Or back up a single path:

```bash
restic backup ~/Documents
```

### List snapshots

```bash
restic snapshots
```

Output looks like:

```
ID        Time                 Host    Paths
---------------------------------------------------------------
a1b2c3d4  2026-04-15 10:30:00  cmos    /home/nicholas/.ssh, ...
e5f6g7h8  2026-04-14 10:30:00  cmos    /home/nicholas/.ssh, ...
```

### Browse a snapshot

Mount all snapshots as a filesystem:

```bash
mkdir -p /tmp/restic-mount
restic mount /tmp/restic-mount
```

Then browse `/tmp/restic-mount/snapshots/<id>/` like normal directories. Ctrl-C to unmount.

Or list files in a specific snapshot without mounting:

```bash
restic ls latest
restic ls latest --path /home/nicholas/.ssh
```

### Restore

Restore a full snapshot:

```bash
restic restore latest --target /tmp/restore
```

Restore specific files:

```bash
restic restore latest --target /tmp/restore --include /home/nicholas/.ssh
```

Restore from a specific snapshot (use the ID from `restic snapshots`):

```bash
restic restore a1b2c3d4 --target /tmp/restore
```

### Diff between snapshots

See what changed between two snapshots:

```bash
restic diff a1b2c3d4 e5f6g7h8
```

## Maintenance

### Check repository integrity

```bash
restic check
```

Deep check (reads all data blobs, slower):

```bash
restic check --read-data
```

### Prune old snapshots

Restic never deletes anything automatically. To apply a retention policy:

```bash
# Keep last 7 daily, 4 weekly, 6 monthly snapshots
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
```

Dry run first to see what would be removed:

```bash
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --dry-run
```

### Unlock a stale lock

If a backup was interrupted (crash, killed process), the repo may be locked:

```bash
restic unlock
```

## Automation

Daily backups run via a systemd user timer, deployed from `config/systemd/user/restic-backup.{service,timer}` by `setup.sh`.

### Why a 1Password service account

Interactive `op read` uses the desktop app integration, which prompts for biometrics/system auth. That is fine for shells but not for a timer that fires at 3 AM with no one logged in.

A 1Password Service Account is the unattended auth path. It is a JWT token (prefix `ops_`) with a scoped vault grant. Set `OP_SERVICE_ACCOUNT_TOKEN=ops_...` and `op` will authenticate against that token directly, no desktop app needed.

### Token file naming

One file per service account. `op` only reads a single env var (`OP_SERVICE_ACCOUNT_TOKEN`), so multiple SAs cannot share an env file. Each systemd unit points its `EnvironmentFile=` at a dedicated file:

```
~/.config/op/SVC_RESTIC_CMOS_ARCH.token       -> OP_SERVICE_ACCOUNT_TOKEN=ops_AAA...
~/.config/op/<future-workload>.token      -> OP_SERVICE_ACCOUNT_TOKEN=ops_BBB...
```

Per-workload SAs give narrow vault scopes, surgical revocation, and clean attribution in the 1Password activity log.

### Setup

1. In the 1Password web UI, create a service account named `SVC_RESTIC_CMOS_ARCH` with read-only access to the `backups` vault only. Store the token itself as a password item in a vault named `op` so you have a recovery reference if the local token file is lost.
2. Copy the token it shows you (only displayed once).
3. Run `~/arch/setup.sh`. When it reaches the restic section and finds no token file, it prompts:

   ```
   Paste token (starts with 'ops_'), or press Enter to skip:
   ```

   Paste the `ops_...` token. Input is hidden. setup.sh validates the `ops_` prefix, writes `~/.config/op/SVC_RESTIC_CMOS_ARCH.token` with `chmod 600` under a `umask 077` subshell, then enables `restic-backup.timer`.

   If the token file already exists, the prompt is skipped and setup.sh just verifies the timer is enabled - so re-runs are silent.

Manual path (if you'd rather skip the prompt, e.g. restoring the file from backup):

```bash
mkdir -p ~/.config/op
umask 077
printf 'OP_SERVICE_ACCOUNT_TOKEN=%s\n' 'ops_...' > ~/.config/op/SVC_RESTIC_CMOS_ARCH.token
chmod 600 ~/.config/op/SVC_RESTIC_CMOS_ARCH.token
```

Then re-run `setup.sh` to enable the timer.

### Operational commands

```bash
# Timer status
systemctl --user status restic-backup.timer
systemctl --user list-timers restic-backup.timer

# Trigger a backup now (out of schedule)
systemctl --user start restic-backup.service

# View last run's logs
journalctl --user -u restic-backup.service -n 200 --no-pager

# Disable automated backups temporarily
systemctl --user disable --now restic-backup.timer
```

### Token rotation

Rotate the service account token from the 1Password web UI, then either:

- delete `~/.config/op/SVC_RESTIC_CMOS_ARCH.token` and re-run `setup.sh` to be prompted for the new value, or
- overwrite the file in place using the manual recipe above.

No restart needed; the next timer fire picks it up (systemd re-reads `EnvironmentFile=` per run for `Type=oneshot`).

### Retention

The timer only runs `restic backup`. It does not prune. Run `restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune` manually from a shell (which uses the desktop app integration) when you want to apply retention. You can add a second timer for this later if desired.

## Tips

- `restic backup` is incremental by default. Only new/changed chunks are uploaded.
- First backup is the slowest. Subsequent runs are fast.
- `--verbose` or `-v` shows per-file progress during backup.
- `--dry-run` works with `backup` to preview what would be sent.
- `--tag` lets you label snapshots (e.g. `--tag pre-upgrade`) for easier filtering later.
- `restic stats` shows total repo size and snapshot counts.

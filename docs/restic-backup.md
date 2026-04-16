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

To avoid typing the repo path and password every time:

```bash
export RESTIC_REPOSITORY="/mnt/syno/backups/restic"
export RESTIC_PASSWORD_COMMAND="op read 'op://Personal/restic/password'"
```

Or with a password file:

```bash
export RESTIC_PASSWORD_FILE="/path/to/password-file"
```

## Daily use

### Back up

Using the config files in `config/restic/`:

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

To run backups on a schedule, create a systemd timer. Example unit files:

**restic-backup.service**:

```ini
[Unit]
Description=Restic backup

[Service]
Type=oneshot
ExecStart=/usr/bin/restic backup --files-from /home/nicholas/arch/config/restic/includes.txt --exclude-file /home/nicholas/arch/config/restic/excludes.txt
Environment=RESTIC_REPOSITORY=/mnt/syno/backups/restic
Environment=RESTIC_PASSWORD_COMMAND=op read 'op://Personal/restic/password'
```

**restic-backup.timer**:

```ini
[Unit]
Description=Daily restic backup

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

Enable with `systemctl --user enable --now restic-backup.timer`.

## Tips

- `restic backup` is incremental by default. Only new/changed chunks are uploaded.
- First backup is the slowest. Subsequent runs are fast.
- `--verbose` or `-v` shows per-file progress during backup.
- `--dry-run` works with `backup` to preview what would be sent.
- `--tag` lets you label snapshots (e.g. `--tag pre-upgrade`) for easier filtering later.
- `restic stats` shows total repo size and snapshot counts.

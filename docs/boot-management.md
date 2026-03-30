# Boot Management (kernel-install + systemd-boot)

## Overview

This system uses `kernel-install` to manage systemd-boot BLS (Boot Loader Specification) entries. Each kernel version gets its own entry at `/boot/arch/<version>/` with a corresponding `/boot/loader/entries/arch-<version>.conf`.

## How it works

1. **Entry token**: `/etc/kernel/entry-token` is set to `arch`, so entries are named `arch-<version>.conf` instead of `<machine-id>-<version>.conf`.
2. **loader.conf**: `default arch-*` ensures systemd-boot always boots the latest Arch kernel by version sort.
3. **Pacman hooks** (deployed by setup.sh to `/etc/pacman.d/hooks/`):
   - `kernel-install.hook` -- runs `kernel-install add-all` post-transaction on kernel install/upgrade
   - `kernel-install-remove.hook` -- runs `kernel-install remove <version>` pre-transaction on kernel removal
4. **mkinitcpio hooks are masked** (`/etc/pacman.d/hooks/60-mkinitcpio-remove.hook` and `90-mkinitcpio-install.hook` symlinked to `/dev/null`). The `kernel-install` plugin `50-mkinitcpio.install` handles initrd generation instead.
5. **cmdline**: `/etc/kernel/cmdline` must NOT contain `initrd=`. The BLS entry's `initrd` field handles this.

## Key files

| File | Purpose |
|------|---------|
| `/etc/kernel/entry-token` | Set to `arch` -- controls entry naming |
| `/etc/kernel/cmdline` | Kernel command line (no initrd= here) |
| `/boot/loader/loader.conf` | `timeout 3` and `default arch-*` |
| `/boot/loader/entries/arch-*.conf` | BLS entries (managed by kernel-install) |
| `/boot/arch/<version>/linux` | Kernel binary |
| `/boot/arch/<version>/initrd` | Initramfs |
| `/etc/pacman.d/hooks/kernel-install.hook` | Pacman hook: add entries on upgrade |
| `/etc/pacman.d/hooks/kernel-install-remove.hook` | Pacman hook: remove entries on uninstall |
| `/etc/pacman.d/hooks/60-mkinitcpio-remove.hook` | Symlink to /dev/null (masked) |
| `/etc/pacman.d/hooks/90-mkinitcpio-install.hook` | Symlink to /dev/null (masked) |
| `/etc/mkinitcpio.d/linux.preset` | Should have default ALL_kver and default_image |

## What setup.sh does on fresh install

1. Sets entry token to `arch`
2. Masks mkinitcpio pacman hooks
3. Strips `initrd=` from cmdline, adds GPU params
4. Sets `default arch-*` in loader.conf
5. Removes stale archinstall boot entries (they point to `/vmlinuz-linux` which kernel-install doesn't update)
6. Migrates any machine-id based entries to arch token
7. Creates initial boot entries via `kernel-install add-all`
8. Deploys pacman hooks for future kernel updates

## Troubleshooting

### Emergency mode after kernel update

**Symptom**: System boots to emergency mode, modprobe errors for missing modules.

**Cause**: A stale boot entry references an old kernel version whose `/usr/lib/modules/<version>/` was removed during the update.

**Fix**:
```bash
# Boot from Arch ISO or use emergency shell
# Mount root and boot partitions
mount /dev/nvme0n1p2 /mnt
mount /dev/nvme0n1p1 /mnt/boot

# Check what entries exist vs what kernels are installed
ls /mnt/boot/loader/entries/
ls /mnt/boot/arch/
ls /mnt/usr/lib/modules/

# Remove stale entries and recreate
arch-chroot /mnt
kernel-install add-all
# Remove any entry that doesn't match an installed kernel version
```

### Verifying the setup is correct

```bash
# Should show arch-<version>.conf as default
bootctl status

# Should show only entries matching installed kernels
ls /boot/loader/entries/
ls /usr/lib/modules/

# Should NOT contain initrd=
cat /etc/kernel/cmdline

# Should be "arch"
cat /etc/kernel/entry-token

# Hooks should be symlinks to /dev/null
ls -la /etc/pacman.d/hooks/60-mkinitcpio-remove.hook
ls -la /etc/pacman.d/hooks/90-mkinitcpio-install.hook

# kernel-install should report layout=bls, token=arch
kernel-install inspect
```

### Double initrd loading

If `/etc/kernel/cmdline` contains `initrd=\initramfs-linux.img`, the boot entry will load two identical initrds (one from the options line, one from the BLS initrd field). Fix by removing the initrd= from cmdline:

```bash
sudo sed -i 's/initrd=[^ ]* //' /etc/kernel/cmdline
sudo kernel-install add-all
```

## History

This setup was introduced after a kernel update (6.19.8 to 6.19.10) caused emergency mode boot. The root cause was that `setup.sh` called `kernel-install add` once (to apply GPU kernel params), which created a BLS entry. But there was no pacman hook to update it on kernel upgrades, so the entry went stale while pacman's mkinitcpio hook only updated the legacy flat files (`/boot/vmlinuz-linux`). The stale entry booted the old kernel binary, which couldn't find its modules (already replaced by the new version).

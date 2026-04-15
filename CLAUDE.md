# ~/arch

Idempotent Arch Linux post-install setup script and config files for a personal workstation. The single entry point is `./setup.sh`, which installs packages, enables services, and deploys config files.

## Architecture

- `setup.sh` - Main bash script. Idempotent: uses `--needed` flags, `command -v` guards, and `systemctl is-enabled` checks so re-runs are safe.
- `packages/official.txt` - Pacman packages, one per line, alphabetically sorted. This is the single source of truth for all official packages.
- `packages/aur.txt` - AUR packages (installed via paru), same format. Does not include custom forks or bootstrapped packages (paru, lite-xl-custom, foot-custom) -- those are built directly from GitHub repos in setup.sh via `makepkg -si` with a `pacman -Q` guard for idempotency.
- All systemd service enables are inline in `setup.sh`, co-located with their config deployment. Config-free services (NetworkManager, greetd, pcscd, tailscaled) are enabled early; config-dependent services are enabled after their config is deployed.
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
6. Custom forks (lite-xl-custom, foot-custom) built from GitHub via makepkg if missing
7. Nix via Determinate Systems installer if missing
8. Claude Code if missing
9. Enable and start systemd services (including `pcscd` for YubiKey)
10. AMD GPU kernel params
11. Font rendering (system-level fontconfig in `/etc/fonts/conf.d/`)
12. KDE settings (lock screen, hot corners, dark theme)
13. Mount points (data disk + NAS, explicit mount for mid-script access)
14. SSH key restore from NAS (age-encrypted, YubiKey decryption — prompts for YubiKey)
15. Git/GitHub config (interactive `gh auth login` with YubiKey passkey)
16. SSH server config
17. Deploy config files (copy KDE configs including monitor layout, symlink the rest)
18. Bluetooth pairing (background scan with polling)

## Desktop Environment

KDE Plasma 6 on Wayland. Stack: KDE Plasma + KWin + greetd/tuigreet (login) + Thunar/Dolphin (file managers) + BreezeDark (theme).

## AI Tooling

Scripts in `bin/` use AI for document filing, commit message generation, and other automation. Two backends are supported:

- **Ollama** (local) -- HTTP API at `localhost:11434`. Used for vision tasks (image-based document filing) and text tasks (commit messages, OCR-based filing). Models vary by script (vision models for images, small text models for lightweight tasks). No authentication required.
- **Claude** (remote) -- Via the `claude-agent-sdk` Python package, which spawns the Claude Code CLI as a subprocess. Inherits CLI authentication from `~/.claude/.credentials.json` (no API key needed with a Max/Pro plan). Used when higher accuracy is needed (e.g. PDF reading where the model reads the file directly via its tool use).

### Provider abstraction

`bin/ai-provider` is a shared bash library that scripts source to get a `try_ai_file()` function. It implements a cascade: try the primary provider, fall back to the other, then fall back to a date-based default. Provider selection is configured in `config/ai/provider.conf` and can be overridden per-script or per-invocation via env vars. Environment defaults for Ollama (URL, model, backend type) live in `config/environment.d/30-ai.conf`.

### Conventions for new AI scripts

- Bash scripts call Ollama directly via `curl` to the HTTP API. Python scripts can use `urllib.request` or the `claude_agent_sdk`.
- Scripts that use the Claude Agent SDK use the repo's Python venv (`~/arch/.venv/`) via a shebang of `#!/home/nicholas/arch/.venv/bin/python`.
- AI scripts go in `bin/` and should fail gracefully (exit 1) so callers can fall back.
- Shared logic (folder context gathering, filename sanitization, fuzzy matching, deduplication) is factored into importable helpers in `bin/` rather than duplicated.

## Key Backup and Restoration

SSH key and Nix store signing key are individually encrypted with `age -p` (passphrase) and stored on the NAS at `/mnt/syno/security/cmos-arch/`. Each key uses its own passphrase (do not bundle into a single archive). The signing key is required for `nixos-rebuild --target-host` to misc/jimmich (servers trust the `cmos-arch` public key). On fresh install, `setup.sh` restores both keys automatically.

```bash
# Encrypt a key for backup
age -e -p -o /mnt/syno/security/cmos-arch/<name>.age /path/to/secret

# Decrypt a key from backup
age -d -o /path/to/secret /mnt/syno/security/cmos-arch/<name>.age
```

| File | Purpose |
|------|---------|
| `id_ed25519.age` | SSH private key |
| `id_ed25519.pub` | SSH public key (unencrypted) |
| `nix-signing-key.age` | Nix store signing key (signs paths for remote rebuilds) |

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
- **Keep AUR audit prompts in sync.** When changing the system stack (adding/removing packages, services, drivers, networking, audio, display, virtualization, or gaming components), update the `TARGET SYSTEM` line in both `config/shell/audit-pkgbuild.sh` and `tools/check-updates.sh` to reflect the change. If the change introduces a new category of stability risk not covered by the existing checklist items, add it.

## check-drift (tools/check-drift.sh)

Detects when deployed config copies have diverged from the repo. Only **copied** configs need drift checking - symlinked configs point directly to the repo and cannot drift.

- When adding a new `copy_config` deployment or `sudo cp` to setup.sh, add a matching `check` line to `tools/check-drift.sh`.
- Do NOT add entries for `link_config` deployments (symlinks don't drift).
- Do NOT add entries for configs that are routinely modified by their application at runtime (e.g. Lutris game configs, CurseForge). Drift checking those would just produce noise.
- Configs that are only read from the repo at runtime (e.g. `config/age/yubikey-identity.txt`) or only used by the installer (e.g. `config/autostart/first-login.desktop`) are not deployed by setup.sh and do not need drift entries.
- Scripts that are executed by setup.sh rather than deployed (e.g. `config/kwin/setup-kwin-scripts.sh`) also do not need drift entries.

## Python Virtual Environment

A shared Python venv lives at `~/arch/.venv/` (gitignored). Use this for any Python dependencies needed by scripts or tools. Activate with `~/arch/.venv/bin/python` or `~/arch/.venv/bin/pip`.

## System Audit

Compare live system state against what the repo declares. Run when asked to "audit my system" or "system audit." Check for:

- Packages explicitly installed (`pacman -Qqe`) but not in `official.txt`, `aur.txt`, the archinstall JSON, or setup.sh's custom fork builds.
- Packages in `official.txt`/`aur.txt` but not actually installed.
- Enabled systemd services (system and user) not in setup.sh.
- Config directories in `~/.config/` not managed by the repo's `config/`.
- Manual binaries in `/usr/local/bin/`, `~/.local/bin/`, `~/.cargo/bin/` not accounted for.
- Flatpaks, nix profiles, uv tools, npm globals, and other non-pacman package state.
- Systemd timers and cron jobs.

When reporting, distinguish between things that should be declared (action needed) and things that are legitimately handled elsewhere (archinstall, setup.sh bootstrap, package dependencies).

## Key Conventions

- All idempotency must be preserved when modifying `setup.sh` - never add operations that fail or duplicate on re-run.
- Both `official.txt` and `aur.txt` are flat alphabetical lists with no comments or categories.
- **Every config file must live in this repo and be deployed to its target location.** Never create or edit config files directly in `~/.config/` or elsewhere - always add them under `config/` in this repo and deploy via `setup.sh`. The repo is the single source of truth for all configuration. KDE configs are copied (not symlinked) because KConfig's QSaveFile atomic writes break symlinks. System configs under `/etc/` are also copied (require root ownership). System-level fontconfig uses symlinks from `/usr/share/fontconfig/conf.avail/` to `/etc/fonts/conf.d/`.
- The script targets a single machine with AMD RX 6800 XT GPU and Intel i7-13700K.
